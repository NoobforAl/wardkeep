package killswitch

import (
	"errors"
	"net/netip"
	"slices"
	"strings"
	"testing"
)

func find(rules []Rule, fam Family, dir Direction, nameSub string) []Rule {
	var out []Rule
	for _, r := range rules {
		if r.Family == fam && r.Direction == dir && strings.Contains(r.Name, nameSub) {
			out = append(out, r)
		}
	}
	return out
}

func condValues(t *testing.T, r Rule, f Field) []any {
	t.Helper()
	for _, c := range r.Conditions {
		if c.Field == f {
			return c.Values
		}
	}
	t.Fatalf("rule %q has no %v condition", r.Name, f)
	return nil
}

func baseOptions() Options {
	return Options{
		ServerAddrs: []netip.Addr{netip.MustParseAddr("203.0.113.7"), netip.MustParseAddr("2001:db8::7")},
		TunLUID:     0x6001000000000,
		Apps:        []string{`C:\Program Files\Omnitun\omnitun-svc.exe`},
		AllowLAN:    true,
	}
}

func TestBuildCoversBothFamiliesAndDirections(t *testing.T) {
	rules, err := Build(baseOptions())
	if err != nil {
		t.Fatal(err)
	}
	for _, fam := range []Family{IPv4, IPv6} {
		for _, dir := range []Direction{Outbound, Inbound} {
			blocks := find(rules, fam, dir, "block everything")
			if len(blocks) != 1 || blocks[0].Action != Block || len(blocks[0].Conditions) != 0 {
				t.Errorf("IPv%d %v: want exactly one unconditional block rule, got %+v", fam, dir, blocks)
			}
			for _, what := range []string{"loopback", "tunnel adapter", "programs", "VPN servers", "local network"} {
				if got := find(rules, fam, dir, what); len(got) != 1 || got[0].Action != Permit {
					t.Errorf("IPv%d %v: want one permit rule %q, got %d", fam, dir, what, len(got))
				}
			}
		}
	}
	// DHCP is per family; neighbour discovery is IPv6 only.
	if len(find(rules, IPv4, Outbound, "DHCP")) != 1 || len(find(rules, IPv6, Outbound, "DHCPv6")) != 1 {
		t.Error("DHCP rules missing")
	}
	if len(find(rules, IPv4, Outbound, "neighbour")) != 0 || len(find(rules, IPv6, Inbound, "neighbour")) != 1 {
		t.Error("neighbour discovery must be IPv6 only")
	}
}

func TestBlockIsTheLowestWeight(t *testing.T) {
	rules, err := Build(baseOptions())
	if err != nil {
		t.Fatal(err)
	}
	for _, r := range rules {
		if r.Action == Block {
			continue
		}
		if r.Weight <= weightBlock {
			t.Errorf("permit %q has weight %d, not above the block rule's %d", r.Name, r.Weight, weightBlock)
		}
	}
}

func TestServersAreSplitByFamily(t *testing.T) {
	rules, _ := Build(baseOptions())
	v4 := condValues(t, find(rules, IPv4, Outbound, "VPN servers")[0], RemoteAddress)
	v6 := condValues(t, find(rules, IPv6, Outbound, "VPN servers")[0], RemoteAddress)
	if len(v4) != 1 || v4[0] != netip.MustParsePrefix("203.0.113.7/32") {
		t.Errorf("IPv4 servers: %v", v4)
	}
	if len(v6) != 1 || v6[0] != netip.MustParsePrefix("2001:db8::7/128") {
		t.Errorf("IPv6 servers: %v", v6)
	}
}

func TestIPv4MappedServerCountsAsIPv4(t *testing.T) {
	o := baseOptions()
	o.ServerAddrs = []netip.Addr{netip.MustParseAddr("::ffff:198.51.100.9")}
	rules, _ := Build(o)
	v4 := find(rules, IPv4, Outbound, "VPN servers")
	if len(v4) != 1 || condValues(t, v4[0], RemoteAddress)[0] != netip.MustParsePrefix("198.51.100.9/32") {
		t.Fatalf("a mapped address must be permitted as the IPv4 address: %+v", v4)
	}
	if len(find(rules, IPv6, Outbound, "VPN servers")) != 0 {
		t.Error("no IPv6 server rule expected")
	}
}

func TestNoServersMeansNoServerRule(t *testing.T) {
	o := baseOptions()
	o.ServerAddrs = nil
	rules, _ := Build(o)
	if got := find(rules, IPv4, Outbound, "VPN servers"); len(got) != 0 {
		t.Errorf("unexpected server rule: %+v", got)
	}
}

func TestWhileConnectingThereIsNoTunnelRule(t *testing.T) {
	o := baseOptions()
	o.TunLUID = 0
	rules, _ := Build(o)
	if got := find(rules, IPv4, Outbound, "tunnel adapter"); len(got) != 0 {
		t.Errorf("tunnel rule before the tunnel exists: %+v", got)
	}
	if got := find(rules, IPv4, Outbound, "programs"); len(got) != 1 {
		t.Error("the core's own traffic must stay open while connecting")
	}
}

func TestTunnelRuleUsesTheLUID(t *testing.T) {
	rules, _ := Build(baseOptions())
	got := condValues(t, find(rules, IPv4, Inbound, "tunnel adapter")[0], LocalInterface)
	if len(got) != 1 || got[0] != uint64(0x6001000000000) {
		t.Errorf("tunnel LUID: %v", got)
	}
}

func TestLANIsOptional(t *testing.T) {
	o := baseOptions()
	o.AllowLAN = false
	rules, _ := Build(o)
	if got := find(rules, IPv4, Outbound, "local network"); len(got) != 0 {
		t.Errorf("LAN rule without AllowLAN: %+v", got)
	}
	o.AllowLAN = true
	rules, _ = Build(o)
	lan4 := condValues(t, find(rules, IPv4, Outbound, "local network")[0], RemoteAddress)
	for _, want := range []string{"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "224.0.0.0/4"} {
		if !slices.Contains(lan4, any(netip.MustParsePrefix(want))) {
			t.Errorf("IPv4 LAN rule lacks %s", want)
		}
	}
	for _, v := range lan4 {
		if v.(netip.Prefix).Addr().Is6() {
			t.Errorf("IPv6 range %v in the IPv4 LAN rule", v)
		}
	}
	lan6 := condValues(t, find(rules, IPv6, Outbound, "local network")[0], RemoteAddress)
	for _, want := range []string{"fe80::/10", "fc00::/7", "ff00::/8"} {
		if !slices.Contains(lan6, any(netip.MustParsePrefix(want))) {
			t.Errorf("IPv6 LAN rule lacks %s", want)
		}
	}
}

func TestPublicAddressesAreNeverInTheLANRule(t *testing.T) {
	for _, p := range append(slices.Clone(lan4), lan6...) {
		for _, pub := range []string{"1.1.1.1", "8.8.8.8", "93.184.216.34", "2606:4700:4700::1111"} {
			if p.Contains(netip.MustParseAddr(pub)) {
				t.Errorf("%v contains the public address %s", p, pub)
			}
		}
	}
}

func TestDHCPAndNDPPorts(t *testing.T) {
	rules, _ := Build(baseOptions())
	d4 := find(rules, IPv4, Outbound, "DHCP")[0]
	if condValues(t, d4, LocalPort)[0] != uint16(68) || condValues(t, d4, RemotePort)[0] != uint16(67) || condValues(t, d4, Protocol)[0] != ProtoUDP {
		t.Errorf("DHCP rule: %+v", d4)
	}
	nd := find(rules, IPv6, Outbound, "neighbour")[0]
	types := condValues(t, nd, LocalPort)
	if len(types) != 5 || types[0] != uint16(133) || types[4] != uint16(137) || condValues(t, nd, Protocol)[0] != ProtoICMPv6 {
		t.Errorf("neighbour discovery rule: %+v", nd)
	}
}

// A permit on the DHCP ports alone would be a way out for any program: the
// outgoing rules must name where the messages may go.
func TestOutgoingDHCPIsLimitedToTheLink(t *testing.T) {
	rules, _ := Build(Options{}) // no LAN rule, no servers: only the DHCP permits are left
	d4 := find(rules, IPv4, Outbound, "DHCP")[0]
	got4 := condValues(t, d4, RemoteAddress)
	if len(got4) != 1 || got4[0] != netip.MustParsePrefix("255.255.255.255/32") {
		t.Errorf("IPv4 DHCP may go to %v, want the broadcast address only", got4)
	}
	d6 := find(rules, IPv6, Outbound, "DHCPv6")[0]
	got6 := condValues(t, d6, RemoteAddress)
	for _, want := range []string{"ff02::1:2/128", "ff05::1:3/128", "fe80::/10"} {
		if !slices.Contains(got6, any(netip.MustParsePrefix(want))) {
			t.Errorf("DHCPv6 lacks %s: %v", want, got6)
		}
	}
	// Nothing that routes beyond the link, and in particular nothing public.
	for _, v := range append(got4, got6...) {
		p := v.(netip.Prefix)
		for _, pub := range []string{"1.1.1.1", "8.8.8.8", "2606:4700:4700::1111"} {
			if p.Contains(netip.MustParseAddr(pub)) {
				t.Errorf("%v contains the public address %s", p, pub)
			}
		}
		if p.Bits() == 0 {
			t.Errorf("%v is everything", p)
		}
	}
	// Replies come from a server nobody knows in advance: no address condition.
	for _, r := range []Rule{find(rules, IPv4, Inbound, "DHCP")[0], find(rules, IPv6, Inbound, "DHCPv6")[0]} {
		for _, c := range r.Conditions {
			if c.Field == RemoteAddress {
				t.Errorf("%q: incoming replies cannot be limited by address", r.Name)
			}
		}
	}
}

func TestExtraRangesAreSplitAndMasked(t *testing.T) {
	o := baseOptions()
	for i := range 600 {
		o.AllowRanges = append(o.AllowRanges, netip.PrefixFrom(netip.AddrFrom4([4]byte{100, byte(i >> 8), byte(i), 0}), 24))
	}
	o.AllowRanges = append(o.AllowRanges, netip.MustParsePrefix("2a00:1450::/32"), netip.MustParsePrefix("100.64.1.77/10"))
	rules, err := Build(o)
	if err != nil {
		t.Fatal(err)
	}
	v4 := find(rules, IPv4, Outbound, "bypass ranges")
	if len(v4) != 3 { // 601 ranges, 256 per rule
		t.Fatalf("want 3 IPv4 rules for 601 ranges, got %d", len(v4))
	}
	total := 0
	for _, r := range v4 {
		total += len(condValues(t, r, RemoteAddress))
	}
	if total != 601 {
		t.Errorf("IPv4 ranges in rules: %d, want 601", total)
	}
	last := condValues(t, v4[2], RemoteAddress)
	if last[len(last)-1] != netip.MustParsePrefix("100.64.0.0/10") {
		t.Errorf("a range with host bits must be masked, got %v", last[len(last)-1])
	}
	if got := find(rules, IPv6, Outbound, "bypass ranges"); len(got) != 1 {
		t.Errorf("IPv6 range rules: %d", len(got))
	}
}

func TestTooManyRangesIsAnError(t *testing.T) {
	o := baseOptions()
	for i := range MaxRanges + 1 {
		o.AllowRanges = append(o.AllowRanges, netip.PrefixFrom(netip.AddrFrom4([4]byte{100, byte(i >> 8), byte(i), 0}), 24))
	}
	if _, err := Build(o); !errors.Is(err, ErrTooManyRanges) {
		t.Fatalf("got %v, want ErrTooManyRanges", err)
	}
	o.AllowRanges = o.AllowRanges[:MaxRanges]
	if _, err := Build(o); err != nil {
		t.Errorf("exactly MaxRanges must be fine: %v", err)
	}
}

func TestInvalidOptions(t *testing.T) {
	for name, o := range map[string]Options{
		"server": {ServerAddrs: []netip.Addr{{}}},
		"range":  {AllowRanges: []netip.Prefix{{}}},
		"app":    {Apps: []string{""}},
	} {
		if _, err := Build(o); err == nil {
			t.Errorf("%s: expected an error", name)
		}
	}
}

func TestBuildIsDeterministic(t *testing.T) {
	a, _ := Build(baseOptions())
	b, _ := Build(baseOptions())
	if len(a) != len(b) {
		t.Fatal("different lengths")
	}
	for i := range a {
		if a[i].Name != b[i].Name || a[i].Weight != b[i].Weight || len(a[i].Conditions) != len(b[i].Conditions) {
			t.Fatalf("rule %d differs", i)
		}
	}
}

// A rule that mixes address families would be rejected by the firewall.
func TestRulesNeverMixFamilies(t *testing.T) {
	o := baseOptions()
	o.AllowRanges = []netip.Prefix{netip.MustParsePrefix("10.9.0.0/16"), netip.MustParsePrefix("fd00::/8")}
	rules, _ := Build(o)
	for _, r := range rules {
		for _, c := range r.Conditions {
			if c.Field != RemoteAddress {
				continue
			}
			for _, v := range c.Values {
				if is4 := v.(netip.Prefix).Addr().Is4(); is4 != (r.Family == IPv4) {
					t.Errorf("rule %q (IPv%d) holds %v", r.Name, r.Family, v)
				}
			}
		}
	}
}
