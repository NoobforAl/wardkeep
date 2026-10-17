package hostproto

import (
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/protocols"
)

// The IPv6 client networks get their own nftables table: replies in, no way to the host's
// private networks (unique local, link-local, loopback) or to each other, the internet out,
// and masquerade; the IPv4 table stays as it was.
func TestNftRulesForIPv6Pools(t *testing.T) {
	text := nftRules([]string{"10.9.0.0/24", "fd31:0:0:1::/64", "fd10:10:10::/64"})
	v4, v6, ok := strings.Cut(text, "table ip6 ")
	if !ok || !strings.HasPrefix(v4, "table ip omnitun_hosts") {
		t.Fatalf("expected an ip table and an ip6 table:\n%s", text)
	}
	if strings.Contains(v4, "fd31") || strings.Contains(v4, "ip6") {
		t.Errorf("IPv6 leaked into the IPv4 table:\n%s", v4)
	}
	v6 = "table ip6 " + v6
	for _, want := range []string{
		"table ip6 omnitun_hosts",
		"ct state established,related ip6 daddr { fd10:10:10::/64, fd31:0:0:1::/64 } accept",
		"ip6 saddr { fd10:10:10::/64, fd31:0:0:1::/64 } ip6 daddr { fc00::/7, fe80::/10, ::1/128, fd10:10:10::/64, fd31:0:0:1::/64 } drop",
		"ip6 saddr { fd10:10:10::/64, fd31:0:0:1::/64 } accept",
		"ip6 daddr { fd10:10:10::/64, fd31:0:0:1::/64 } drop",
		"ip6 saddr { fd10:10:10::/64, fd31:0:0:1::/64 } masquerade",
	} {
		if !strings.Contains(v6, want) {
			t.Errorf("the ip6 table lacks %q:\n%s", want, v6)
		}
	}
	if only := nftRules([]string{"fd31:0:0:1::/64"}); strings.Contains(only, "table ip ") {
		t.Errorf("an IPv6-only server got an IPv4 table:\n%s", only)
	}
}

func TestEnableNATWithBothFamilies(t *testing.T) {
	dir := tempDir(t)
	r := &fakeRunner{have: map[string]bool{"nft": true}}
	undo, err := EnableNAT(r, dir, []string{"10.31.0.0/16", "fd31:0:0:1::/64"})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"nft delete table ip omnitun_hosts", "nft delete table ip6 omnitun_hosts"}
	if len(r.ran) != 3 || r.ran[0] != want[0] || r.ran[1] != want[1] || !strings.HasPrefix(r.ran[2], "nft -f ") {
		t.Fatalf("commands = %v", r.ran)
	}
	r.ran = nil
	undo()
	if len(r.ran) != 2 || r.ran[0] != want[0] || r.ran[1] != want[1] {
		t.Fatalf("undo ran %v", r.ran)
	}
}

func TestEnableNATWithIPTablesForIPv6(t *testing.T) {
	r := &fakeRunner{have: map[string]bool{"iptables": true, "ip6tables": true}}
	undo, err := EnableNAT(r, tempDir(t), []string{"10.31.0.0/16", "fd31:0:0:1::/64"})
	if err != nil {
		t.Fatal(err)
	}
	all := strings.Join(r.ran, "\n")
	for _, w := range []string{
		"iptables -t nat -A POSTROUTING -s 10.31.0.0/16 -j MASQUERADE",
		"ip6tables -t nat -A POSTROUTING -s fd31:0:0:1::/64 -j MASQUERADE",
		"ip6tables -I FORWARD 1 -s fd31:0:0:1::/64 -d fc00::/7 -j DROP",
		"ip6tables -I FORWARD 1 -s fd31:0:0:1::/64 -j ACCEPT",
	} {
		if !strings.Contains(all, w) {
			t.Errorf("missing %q:\n%s", w, all)
		}
	}
	if strings.Contains(all, "iptables -I FORWARD 1 -s 10.31.0.0/16 -d fd") || strings.Contains(all, "ip6tables -I FORWARD 1 -s fd31:0:0:1::/64 -d 10.") {
		t.Errorf("a rule mixes the families:\n%s", all)
	}
	n := len(r.ran)
	r.ran = nil
	undo()
	if len(r.ran) != n || !strings.Contains(strings.Join(r.ran, "\n"), "ip6tables -t nat -D POSTROUTING -s fd31:0:0:1::/64 -j MASQUERADE") {
		t.Fatalf("undo ran %d commands for %d rules:\n%v", len(r.ran), n, r.ran)
	}
	// No ip6tables: IPv6 cannot be offered, and what was added is taken back.
	r = &fakeRunner{have: map[string]bool{"iptables": true}}
	if _, err := EnableNAT(r, tempDir(t), []string{"10.31.0.0/16", "fd31:0:0:1::/64"}); err == nil || !strings.Contains(err.Error(), "ip6tables") {
		t.Fatalf("IPv6 without ip6tables: %v", err)
	}
	if !strings.Contains(strings.Join(r.ran, "\n"), "-t nat -D POSTROUTING -s 10.31.0.0/16") {
		t.Errorf("the IPv4 rules were not taken back: %v", r.ran)
	}
}

// With IPv6 on, the AmneziaWG server accepts each user's IPv6 address, gives the
// interface its own, and reports the network for NAT; with it off none of that happens.
func TestAmneziaWGServerWithIPv6(t *testing.T) {
	for _, on := range []bool{false, true} {
		fakeTunOpener(t)
		e, user := awgEnv(t)
		e.IPv6 = on
		uapi, _, err := awgUAPI(Config{Env: e, Port: 51821, Users: []protocols.Account{user}})
		if err != nil {
			t.Fatal(err)
		}
		if got := strings.Contains(uapi, "allowed_ip=fd31:0:0:1::2/128\n"); got != on || !strings.Contains(uapi, "allowed_ip=10.31.0.2/32\n") {
			t.Errorf("IPv6 %v: allowed_ip lines are wrong:\n%s", on, uapi)
		}
		run := &fakeRunner{}
		srv, err := Start("amneziawg", Config{Env: e, Port: freeUDP(t), Users: []protocols.Account{user}, Runner: run})
		if err != nil {
			t.Fatal(err)
		}
		ran := strings.Join(run.ran, "\n")
		if got := strings.Contains(ran, "ip -6 addr add fd31:0:0:1::1/64 dev omnitun-awg"); got != on {
			t.Errorf("IPv6 %v: commands:\n%s", on, ran)
		}
		pool6 := srv.(DualStack).Pool6()
		if (pool6 == protocols.AWGPool6) != on || (!on && pool6 != "") {
			t.Errorf("IPv6 %v: Pool6 = %q", on, pool6)
		}
		srv.Close()
	}
}
