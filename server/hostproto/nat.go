package hostproto

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"sort"
	"strings"
)

// Runner executes a command; tests replace it.
type Runner interface {
	Run(argv ...string) error
	// Has reports whether a command exists on this host.
	Has(name string) bool
}

// ExecRunner runs real commands.
type ExecRunner struct{}

// Run implements Runner.
func (ExecRunner) Run(argv ...string) error {
	out, err := exec.Command(argv[0], argv[1:]...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %w: %s", strings.Join(argv, " "), err, strings.TrimSpace(string(out)))
	}
	return nil
}

// Has implements Runner.
func (ExecRunner) Has(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// natTable is the nftables table the server owns; it is removed on stop.
const natTable = "omnitun_hosts"

// privateRanges are never reachable from clients: their traffic leaves the
// host towards the internet, not towards the server's own network.
var privateRanges = []string{
	"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "100.64.0.0/10", "127.0.0.0/8",
}

// privateRanges6 are the IPv6 counterparts: unique local, link-local and loopback.
// The client pools themselves are unique local addresses, so they are inside the first.
var privateRanges6 = []string{"fc00::/7", "fe80::/10", "::1/128"}

// splitPools separates IPv4 and IPv6 networks.
func splitPools(pools []string) (v4, v6 []string) {
	for _, p := range pools {
		if strings.Contains(p, ":") {
			v6 = append(v6, p)
		} else {
			v4 = append(v4, p)
		}
	}
	return v4, v6
}

// nftRules is the ruleset for the client pools. Forwarding is deliberately
// narrow: replies may return to the pools, clients may reach the internet,
// and everything else (client to client, client to the host's private
// networks, unsolicited traffic towards a client) is dropped. Masquerade
// covers what leaves the host.
func nftRules(pools []string) string {
	v4, v6 := splitPools(pools)
	var out string
	if len(v4) > 0 {
		out += nftTable("ip", "ip", v4, privateRanges)
	}
	if len(v6) > 0 {
		out += nftTable("ip6", "ip6", v6, privateRanges6)
	}
	return out
}

// nftTable is the ruleset of one address family (family is nft's name for it
// and the keyword in the rules).
func nftTable(family, kw string, pools, privateNets []string) string {
	sorted := append([]string(nil), pools...)
	sort.Strings(sorted)
	set := strings.Join(sorted, ", ")
	private := strings.Join(append(append([]string(nil), privateNets...), sorted...), ", ")
	return fmt.Sprintf(`table %[4]s %[1]s {
	chain forward {
		type filter hook forward priority -1; policy accept;
		ct state established,related %[5]s daddr { %[2]s } accept
		%[5]s saddr { %[2]s } %[5]s daddr { %[3]s } drop
		%[5]s saddr { %[2]s } accept
		%[5]s daddr { %[2]s } drop
	}
	chain postrouting {
		type nat hook postrouting priority 100; policy accept;
		%[5]s saddr { %[2]s } masquerade
	}
}
`, natTable, set, private, family, kw)
}

// sameFamily keeps the networks of pool's address family.
func sameFamily(pool string, all []string) []string {
	var out []string
	for _, a := range all {
		if strings.Contains(a, ":") == strings.Contains(pool, ":") {
			out = append(out, a)
		}
	}
	return out
}

// iptablesRules are the same policy as iptables rules, in the order they
// must match (first to last); each is inserted at the top of FORWARD.
func iptablesRules(pool string, all []string) [][]string {
	private := privateRanges
	if strings.Contains(pool, ":") {
		private = privateRanges6
	}
	rules := [][]string{
		{"-d", pool, "-m", "conntrack", "--ctstate", "ESTABLISHED,RELATED", "-j", "ACCEPT"},
	}
	for _, dst := range append(append([]string(nil), private...), sameFamily(pool, all)...) {
		rules = append(rules, []string{"-s", pool, "-d", dst, "-j", "DROP"})
	}
	return append(rules,
		[]string{"-s", pool, "-j", "ACCEPT"},
		[]string{"-d", pool, "-j", "DROP"},
	)
}

// EnableNAT lets clients of the given pools reach the internet through this
// host (and nothing else, see nftRules) and returns a function that removes
// the rules again. It uses nftables and falls back to iptables. dir is where
// the nft ruleset file is written.
func EnableNAT(r Runner, dir string, pools []string) (undo func(), err error) {
	if len(pools) == 0 {
		return func() {}, nil
	}
	switch {
	case r.Has("nft"):
		file := filepath.Join(dir, "nat.nft")
		if err := os.WriteFile(file, []byte(nftRules(pools)), 0o600); err != nil {
			return nil, err
		}
		// Start clean if a crashed run left the tables behind.
		v4, v6 := splitPools(pools)
		var families []string
		if len(v4) > 0 {
			families = append(families, "ip")
		}
		if len(v6) > 0 {
			families = append(families, "ip6")
		}
		for _, f := range families {
			r.Run("nft", "delete", "table", f, natTable)
		}
		if err := r.Run("nft", "-f", file); err != nil {
			os.Remove(file)
			return nil, err
		}
		return func() {
			for _, f := range families {
				r.Run("nft", "delete", "table", f, natTable)
			}
			os.Remove(file)
		}, nil
	case r.Has("iptables"):
		type removal struct {
			tool string
			args []string
		}
		var removals []removal // commands that take back what was added, newest first
		undo := func() {
			for _, rule := range removals {
				r.Run(append([]string{rule.tool}, rule.args...)...)
			}
		}
		for _, p := range pools {
			tool := "iptables"
			if strings.Contains(p, ":") {
				if !r.Has("ip6tables") {
					undo()
					return nil, fmt.Errorf("ip6tables is not installed, so IPv6 clients could not reach the internet")
				}
				tool = "ip6tables"
			}
			add := func(add, del []string) error {
				if err := r.Run(append([]string{tool}, add...)...); err != nil {
					return err
				}
				removals = append([]removal{{tool, del}}, removals...)
				return nil
			}
			if err := add([]string{"-t", "nat", "-A", "POSTROUTING", "-s", p, "-j", "MASQUERADE"},
				[]string{"-t", "nat", "-D", "POSTROUTING", "-s", p, "-j", "MASQUERADE"}); err != nil {
				undo()
				return nil, err
			}
			rules := iptablesRules(p, pools)
			// Insert last-to-first so the first rule ends up on top.
			for _, rule := range slices.Backward(rules) {
				if err := add(append([]string{"-I", "FORWARD", "1"}, rule...), append([]string{"-D", "FORWARD"}, rule...)); err != nil {
					undo()
					return nil, err
				}
			}
		}
		return undo, nil
	}
	return nil, fmt.Errorf("neither nft nor iptables is installed, so clients could not reach the internet")
}

// ForwardingEnabled reports whether the kernel forwards IPv4 packets.
func ForwardingEnabled() bool {
	data, err := os.ReadFile("/proc/sys/net/ipv4/ip_forward")
	return err == nil && strings.TrimSpace(string(data)) == "1"
}

// ForwardingEnabled6 reports whether the kernel forwards IPv6 packets.
func ForwardingEnabled6() bool {
	data, err := os.ReadFile("/proc/sys/net/ipv6/conf/all/forwarding")
	return err == nil && strings.TrimSpace(string(data)) == "1"
}
