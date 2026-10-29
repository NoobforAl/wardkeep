package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"strings"
	"time"

	"github.com/NoobforAl/omnitun/core/killswitch"
	"github.com/NoobforAl/omnitun/core/singbox"
	"github.com/NoobforAl/omnitun/core/winsvc"
)

// subcommands are the Windows service's management commands. Each returns
// the process exit code.
var subcommands = map[string]func(args []string) int{
	"install":             cmdInstall,
	"uninstall":           cmdUninstall,
	"start":               cmdStart,
	"stop":                cmdStop,
	"status":              cmdStatus,
	"cleanup":             cmdCleanup,
	"killswitch-selftest": cmdKillSwitchSelfTest,
	"service":             func([]string) int { return runAsService() },
	"help":                func([]string) int { usage(); return 0 },
}

func usage() {
	fmt.Fprint(os.Stderr, `usage: omnitun-svc [flags]                    run the per-user daemon (what the app launches)
       omnitun-svc install [--user NAME]... [--no-copy] [--unsafe-source]
       omnitun-svc uninstall [--purge]
       omnitun-svc start | stop | status
       omnitun-svc cleanup [--force]
       omnitun-svc killswitch-selftest --yes [--seconds N]
The service commands are for Windows; all but status need an elevated terminal.
`)
}

func say(format string, args ...any) { fmt.Printf(format+"\n", args...) }

type stringList []string

func (l *stringList) String() string     { return strings.Join(*l, ",") }
func (l *stringList) Set(v string) error { *l = append(*l, v); return nil }

func fail(err error) int {
	fmt.Fprintln(os.Stderr, "omnitun-svc:", err)
	return 1
}

func cmdInstall(args []string) int {
	fs := newFlagSet("install")
	var users stringList
	fs.Var(&users, "user", "account (name or SID) allowed to drive the VPN through the service; repeatable. Default: the user running this command")
	exe := fs.String("exe", "", "program to install (default: this one)")
	noCopy := fs.Bool("no-copy", false, "register the program where it is, without copying it to Program Files (development only)")
	unsafeSource := fs.Bool("unsafe-source", false, "install even if non-administrators can write to the folder the program comes from (development only)")
	if fs.Parse(args) != nil {
		return 2
	}
	say("Installing the %s service", winsvc.ServiceName)
	if err := winsvc.Install(winsvc.InstallOptions{Exe: *exe, Users: users, NoCopy: *noCopy, UnsafeSource: *unsafeSource}, say); err != nil {
		return fail(err)
	}
	say("Installed. Start it with: omnitun-svc start")
	return 0
}

func cmdUninstall(args []string) int {
	fs := newFlagSet("uninstall")
	purge := fs.Bool("purge", false, "also remove the settings, data and log in ProgramData")
	if fs.Parse(args) != nil {
		return 2
	}
	if err := winsvc.Uninstall(*purge, say); err != nil {
		return fail(err)
	}
	return 0
}

func cmdStart([]string) int {
	if err := winsvc.Start(say); err != nil {
		return fail(err)
	}
	say("The service is running.")
	return 0
}

func cmdStop([]string) int {
	if err := winsvc.Stop(say); err != nil {
		return fail(err)
	}
	return 0
}

// Exit codes of status, for scripts.
const (
	statusOK           = 0 // running and this user can use it
	statusUnreachable  = 2 // running, but this user cannot use it
	statusNotRunning   = 3 // installed, not running
	statusNotInstalled = 4
)

func cmdStatus([]string) int {
	st, err := winsvc.QueryStatus()
	if err != nil {
		return fail(err)
	}
	layout := winsvc.DefaultLayout()
	if !st.Installed {
		say("service: not installed")
		return statusNotInstalled
	}
	say("service: installed, %s", st.State)
	if st.Path != "" {
		say("program: %s", st.Path)
	}
	if cfg, err := winsvc.LoadConfig(layout.Config); err == nil {
		say("allowed accounts: %s", strings.Join(cfg.AllowedSIDs, ", "))
	}
	say("control file: %s", layout.ControlFile)
	if st.State != "running" {
		return statusNotRunning
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cf, err := winsvc.Detect(ctx, layout.ControlFile)
	if err != nil {
		say("this user cannot use the service: %v", err)
		return statusUnreachable
	}
	say("this user can use the service (pid %d, %s)", cf.PID, cf.Addr)
	return statusOK
}

func cmdCleanup(args []string) int {
	fs := newFlagSet("cleanup")
	force := fs.Bool("force", false, "run although the service is running")
	if fs.Parse(args) != nil {
		return 2
	}
	if !winsvc.IsElevated() {
		return fail(winsvc.ErrNeedsAdmin)
	}
	if st, _ := winsvc.QueryStatus(); st.State == "running" && !*force {
		return fail(errors.New("the service is running and owns the tunnel adapter; stop it first (omnitun-svc stop) or use --force"))
	}
	rep := winsvc.RunCleanup(winsvc.CleanupSteps(singbox.WindowsTunName))
	fmt.Print(rep.String())
	if err := rep.Err(); err != nil {
		return fail(err)
	}
	return 0
}

// cmdKillSwitchSelfTest raises a kill switch that lets nothing through but
// loopback, checks that outgoing connections fail, lifts it and checks that
// they work again. For about a second the whole machine is cut off
// from the network, so it asks for --yes and always lifts the block (a timer
// does it too; and the rules vanish with the process).
func cmdKillSwitchSelfTest(args []string) int {
	fs := newFlagSet("killswitch-selftest")
	yes := fs.Bool("yes", false, "confirm: the whole machine loses its network for a few seconds")
	seconds := fs.Int("seconds", 6, "longest the block may last")
	target := fs.String("target", "1.1.1.1:443", "address to try to reach")
	if fs.Parse(args) != nil {
		return 2
	}
	if !*yes {
		return fail(errors.New("this cuts the machine off the network for a few seconds (your VPN too); repeat with --yes"))
	}
	if !winsvc.IsElevated() {
		return fail(winsvc.ErrNeedsAdmin)
	}
	reach := func(addr string) error {
		c, err := (&net.Dialer{Timeout: 2 * time.Second}).DialContext(context.Background(), "tcp", addr)
		if err == nil {
			c.Close()
		}
		return err
	}
	say("1. before: connecting to %s", *target)
	if err := reach(*target); err != nil {
		return fail(fmt.Errorf("cannot reach %s even without the kill switch: %w", *target, err))
	}
	say("   reachable, as expected")

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fail(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			c.Close()
		}
	}()

	ks := killswitch.NewManager()
	timer := time.AfterFunc(time.Duration(*seconds)*time.Second, func() { _ = ks.Disarm() })
	defer timer.Stop()
	defer func() { _ = ks.Disarm() }()
	say("2. raising a block that permits loopback only (lasts at most %d s)", *seconds)
	if err := ks.Arm(killswitch.Options{}, ""); err != nil {
		return fail(err)
	}
	code := 0
	if err := reach(*target); err == nil {
		say("   FAIL: %s is still reachable with the block raised", *target)
		code = 1
	} else {
		say("   blocked, as expected (%v)", err)
	}
	if err := reach(ln.Addr().String()); err != nil {
		say("   FAIL: loopback does not work with the block raised: %v", err)
		code = 1
	} else {
		say("   loopback still works, as expected")
	}
	say("3. lifting the block")
	if err := ks.Disarm(); err != nil {
		return fail(err)
	}
	time.Sleep(300 * time.Millisecond)
	if err := reach(*target); err != nil {
		say("   FAIL: %s is not reachable after the block was lifted: %v", *target, err)
		code = 1
	} else {
		say("   reachable again, as expected")
	}
	if code == 0 {
		say("PASS")
	}
	return code
}
