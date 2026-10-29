// Package install builds and runs the steps that turn a copied binary into a
// running service on a Linux host: a system user, the binary in place, a
// hardened systemd unit and the firewall rules for the configured ports.
//
// The plan is plain data (commands and files), so it can be shown with
// --dry-run, tested without a Linux machine, and executed by a thin runner.
package install

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strconv"
	"strings"
)

// Port is a port the firewall must allow.
type Port struct {
	Port    int
	Proto   string // "tcp" or "udp"
	Purpose string
}

// Options describes the installation.
type Options struct {
	// Binary is the executable to install (usually the running one).
	Binary string
	// BinDir is where it is installed (default /usr/local/bin).
	BinDir string
	// DataDir is the server's data directory (state, keys, certificates).
	DataDir string
	// User runs the service ("" = root). It is created when missing.
	User string
	// Firewall is "auto", "ufw", "firewalld" or "none".
	Firewall string
	Ports    []Port
	// HostServers is true when a host-level protocol (AmneziaWG) is enabled:
	// the service then needs CAP_NET_ADMIN (TUN device, NAT rules) and IP
	// forwarding.
	HostServers bool
}

// Step is one thing the installer does: write a file or run a command.
type Step struct {
	Description string
	// Command is argv; nil for a file step.
	Command []string
	// IgnoreError marks steps that may legitimately fail (a user that
	// exists, a rule that is already there).
	IgnoreError bool
	// File is written (mode FileMode) when Command is nil.
	File     string
	Content  string
	FileMode os.FileMode
}

// Plan is the ordered list of steps plus advice for the person running it.
type Plan struct {
	Steps []Step
	Notes []string
}

// UnitName is the systemd service name.
const UnitName = "omnitun-server"

// SysctlPath enables IP forwarding for the host-level protocols.
const SysctlPath = "/etc/sysctl.d/99-omnitun.conf"

// UnitPath is where the unit is installed.
const UnitPath = "/etc/systemd/system/" + UnitName + ".service"

func (o *Options) defaults() {
	if o.BinDir == "" {
		o.BinDir = "/usr/local/bin"
	}
	if o.Firewall == "" {
		o.Firewall = "auto"
	}
}

// Unit returns the systemd unit for the server. It is also what
// `omnitun-server service` prints.
func Unit(binary, dataDir, user string, hostServers bool) string {
	var out strings.Builder
	out.WriteString("[Unit]\nDescription=Wardkeep VPN server\nAfter=network-online.target\nWants=network-online.target\n\n[Service]\n")
	fmt.Fprintf(&out, "ExecStart=%s --data %s run\n", binary, dataDir)
	if user != "" {
		fmt.Fprintf(&out, "User=%s\nGroup=%s\n", user, user)
	}
	out.WriteString("Restart=on-failure\nRestartSec=3\nLimitNOFILE=1048576\n")
	// Binding ports below 1024 (443) without being root.
	caps := "CAP_NET_BIND_SERVICE"
	if hostServers {
		caps += " CAP_NET_ADMIN" // the TUN device and the NAT rules of AmneziaWG
	}
	fmt.Fprintf(&out, "AmbientCapabilities=%s\nCapabilityBoundingSet=%s\nNoNewPrivileges=true\n", caps, caps)
	out.WriteString("ProtectSystem=full\nProtectHome=true\nPrivateTmp=true\n")
	fmt.Fprintf(&out, "ReadWritePaths=%s\n", dataDir)
	out.WriteString("\n[Install]\nWantedBy=multi-user.target\n")
	return out.String()
}

// firewallRuleComment tags the rules so uninstall can remove exactly them.
const firewallRuleComment = "omnitun"

func portArg(p Port) string { return strconv.Itoa(p.Port) + "/" + p.Proto }

// firewallSteps returns the commands that open (or close) the ports with the
// given manager.
func firewallSteps(kind string, ports []Port, remove bool) []Step {
	var steps []Step
	for _, port := range ports {
		switch kind {
		case "ufw":
			if remove {
				steps = append(steps, Step{Description: "close " + portArg(port), Command: []string{"ufw", "delete", "allow", portArg(port)}, IgnoreError: true})
			} else {
				steps = append(steps, Step{Description: "open " + portArg(port) + " (" + port.Purpose + ")",
					Command: []string{"ufw", "allow", portArg(port), "comment", firewallRuleComment + ": " + port.Purpose}})
			}
		case "firewalld":
			verb := "--add-port=" + portArg(port)
			desc := "open " + portArg(port) + " (" + port.Purpose + ")"
			if remove {
				verb, desc = "--remove-port="+portArg(port), "close "+portArg(port)
			}
			steps = append(steps, Step{Description: desc, Command: []string{"firewall-cmd", "--permanent", verb}, IgnoreError: remove})
		}
	}
	if kind == "firewalld" && len(ports) > 0 {
		steps = append(steps, Step{Description: "reload firewalld", Command: []string{"firewall-cmd", "--reload"}})
	}
	return steps
}

// manualFirewallNote tells the person what to allow when no manager is known.
func manualFirewallNote(ports []Port) string {
	var tcp, udp []string
	for _, p := range ports {
		if p.Proto == "tcp" {
			tcp = append(tcp, strconv.Itoa(p.Port))
		} else {
			udp = append(udp, strconv.Itoa(p.Port))
		}
	}
	var out strings.Builder
	out.WriteString("No supported firewall manager (ufw or firewalld) is active, so no rules were added. ")
	out.WriteString("If you use nftables or iptables directly, allow:")
	if len(tcp) > 0 {
		fmt.Fprintf(&out, "\n  TCP: %s\n    nft add rule inet filter input tcp dport { %s } accept", strings.Join(tcp, ", "), strings.Join(tcp, ", "))
	}
	if len(udp) > 0 {
		fmt.Fprintf(&out, "\n  UDP: %s\n    nft add rule inet filter input udp dport { %s } accept", strings.Join(udp, ", "), strings.Join(udp, ", "))
	}
	out.WriteString("\nAlso check your cloud provider's security group or network firewall.")
	return out.String()
}

// Plan builds the installation steps. fw is the detected firewall manager
// ("ufw", "firewalld" or "none"), see Detect.
func BuildPlan(opts Options, fw string) (Plan, error) {
	opts.defaults()
	// Plans describe Linux paths (slashes); a Windows host can still preview one.
	opts.Binary, opts.DataDir, opts.BinDir = filepath.ToSlash(opts.Binary), filepath.ToSlash(opts.DataDir), filepath.ToSlash(opts.BinDir)
	if opts.Binary == "" || opts.DataDir == "" {
		return Plan{}, errors.New("the binary and the data directory are required")
	}
	if !isAbs(opts.DataDir) || !isAbs(opts.BinDir) {
		return Plan{}, errors.New("the data and binary directories must be absolute paths")
	}
	if strings.ContainsAny(opts.DataDir+opts.BinDir+opts.User, " \t\r\n\"'\\$") {
		return Plan{}, errors.New("the directories and user name may not contain spaces or shell characters")
	}
	target := path.Join(opts.BinDir, "omnitun-server")
	var plan Plan
	step := func(desc string, ignore bool, argv ...string) {
		plan.Steps = append(plan.Steps, Step{Description: desc, Command: argv, IgnoreError: ignore})
	}

	if opts.User != "" {
		step("create the service user "+opts.User, true, "useradd", "--system", "--home-dir", opts.DataDir, "--shell", "/usr/sbin/nologin", opts.User)
	}
	step("create the data directory", false, "mkdir", "-p", opts.DataDir)
	if opts.User != "" {
		step("give the service user the data directory", false, "chown", "-R", opts.User+":"+opts.User, opts.DataDir)
	}
	step("restrict the data directory (it holds every key)", false, "chmod", "700", opts.DataDir)
	step("install the binary", false, "install", "-m", "0755", filepath.ToSlash(opts.Binary), target)
	plan.Steps = append(plan.Steps, Step{
		Description: "write the systemd unit", File: UnitPath, FileMode: 0o644,
		Content: Unit(target, filepath.ToSlash(opts.DataDir), opts.User, opts.HostServers),
	})
	if opts.HostServers {
		plan.Steps = append(plan.Steps, Step{
			Description: "enable IP forwarding (AmneziaWG clients are routed through this host)",
			File:        SysctlPath, FileMode: 0o644, Content: "net.ipv4.ip_forward=1\n",
		})
		step("apply the sysctl settings", false, "sysctl", "--system")
	}
	step("reload systemd", false, "systemctl", "daemon-reload")

	kind := opts.Firewall
	if kind == "auto" {
		kind = fw
	}
	switch kind {
	case "ufw", "firewalld":
		plan.Steps = append(plan.Steps, firewallSteps(kind, opts.Ports, false)...)
	default:
		if len(opts.Ports) > 0 {
			plan.Notes = append(plan.Notes, manualFirewallNote(opts.Ports))
		}
	}
	step("start the server now and at every boot", false, "systemctl", "enable", "--now", UnitName)
	plan.Notes = append(plan.Notes, "Check it with: systemctl status "+UnitName+"   and   omnitun-server --data "+filepath.ToSlash(opts.DataDir)+" logs -f")
	return plan, nil
}

// BuildRemovalPlan stops the service and removes the unit and the firewall
// rules it added. The data directory and the binary are left alone.
func BuildRemovalPlan(opts Options, fw string) Plan {
	opts.defaults()
	var plan Plan
	step := func(desc string, argv ...string) {
		plan.Steps = append(plan.Steps, Step{Description: desc, Command: argv, IgnoreError: true})
	}
	step("stop and disable the service", "systemctl", "disable", "--now", UnitName)
	plan.Steps = append(plan.Steps, Step{Description: "remove the systemd unit", Command: []string{"rm", "-f", UnitPath}, IgnoreError: true})
	step("reload systemd", "systemctl", "daemon-reload")
	kind := opts.Firewall
	if kind == "auto" {
		kind = fw
	}
	if kind == "ufw" || kind == "firewalld" {
		plan.Steps = append(plan.Steps, firewallSteps(kind, opts.Ports, true)...)
	}
	plan.Notes = append(plan.Notes, "The data directory "+filepath.ToSlash(opts.DataDir)+" and the binary were kept; delete them yourself if you are sure.")
	return plan
}

// FirewallPlan opens only the firewall ports (after a port was changed).
func FirewallPlan(opts Options, fw string) Plan {
	opts.defaults()
	kind := opts.Firewall
	if kind == "auto" {
		kind = fw
	}
	if kind == "ufw" || kind == "firewalld" {
		return Plan{Steps: firewallSteps(kind, opts.Ports, false)}
	}
	return Plan{Notes: []string{manualFirewallNote(opts.Ports)}}
}

// Runner runs commands; tests replace it.
type Runner interface {
	// Run executes argv and returns its combined output.
	Run(argv ...string) (string, error)
	// Active reports whether the command exits successfully (used to detect
	// the firewall manager).
	Active(argv ...string) bool
}

// ExecRunner runs real commands.
type ExecRunner struct{}

// Run implements Runner.
func (ExecRunner) Run(argv ...string) (string, error) {
	var out bytes.Buffer
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Stdout, cmd.Stderr = &out, &out
	err := cmd.Run()
	return strings.TrimSpace(out.String()), err
}

// Active implements Runner.
func (ExecRunner) Active(argv ...string) bool {
	if _, err := exec.LookPath(argv[0]); err != nil {
		return false
	}
	return exec.Command(argv[0], argv[1:]...).Run() == nil
}

// Detect finds the firewall manager that is switched on: "ufw", "firewalld"
// or "none".
func Detect(runner Runner) string {
	if out, err := runner.Run("ufw", "status"); err == nil && strings.Contains(out, "Status: active") {
		return "ufw"
	}
	if runner.Active("firewall-cmd", "--state") {
		return "firewalld"
	}
	return "none"
}

// Execute runs a plan, reporting each step to w. A failing step that is not
// marked IgnoreError stops the run.
func Execute(plan Plan, runner Runner, w io.Writer) error {
	for i, step := range plan.Steps {
		fmt.Fprintf(w, "[%d/%d] %s\n", i+1, len(plan.Steps), step.Description)
		switch {
		case step.Command == nil:
			if err := os.MkdirAll(filepath.Dir(step.File), 0o755); err != nil {
				return err
			}
			if err := os.WriteFile(step.File, []byte(step.Content), step.FileMode); err != nil {
				return fmt.Errorf("%s: %w", step.Description, err)
			}
		default:
			out, err := runner.Run(step.Command...)
			if err != nil && !step.IgnoreError {
				return fmt.Errorf("%s: %s: %w\n%s", step.Description, strings.Join(step.Command, " "), err, out)
			}
		}
	}
	return nil
}

// Describe prints a plan as shell-like text (for --dry-run).
func Describe(plan Plan, w io.Writer) {
	for _, step := range plan.Steps {
		if step.Command == nil {
			fmt.Fprintf(w, "# %s\n#   write %s\n", step.Description, step.File)
			for line := range strings.SplitSeq(strings.TrimRight(step.Content, "\n"), "\n") {
				fmt.Fprintf(w, "#   | %s\n", line)
			}
			continue
		}
		fmt.Fprintf(w, "# %s\n%s\n", step.Description, strings.Join(step.Command, " "))
	}
	for _, n := range plan.Notes {
		fmt.Fprintf(w, "\nnote: %s\n", n)
	}
}

// isAbs accepts Linux absolute paths, and (so a dry run can be previewed on
// another system) the host's own absolute paths.
func isAbs(p string) bool { return path.IsAbs(filepath.ToSlash(p)) || filepath.IsAbs(p) }
