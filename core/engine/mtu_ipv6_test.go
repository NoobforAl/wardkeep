//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/singbox"
)

func tunOf(t *testing.T, cfg map[string]any) map[string]any {
	t.Helper()
	for _, in := range cfg["inbounds"].([]any) {
		if m := in.(map[string]any); m["type"] == "tun" {
			return m
		}
	}
	t.Fatal("no tun inbound")
	return nil
}

// The TUN's packet size is the default unless the user chose one, and a silly one is refused.
func TestTunMTU(t *testing.T) {
	p, err := importer.ParseLink(testLinks()[0])
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct{ in, want int }{{0, singbox.DefaultMTU}, {1280, 1280}, {1500, 1500}, {65535, 65535}, {576, 576}} {
		cfg, _, err := singbox.Build(p.AsSlice(), singbox.Options{Mode: singbox.ModeTUN, MTU: c.in})
		if err != nil {
			t.Fatalf("mtu %d: %v", c.in, err)
		}
		if got := tunOf(t, cfg)["mtu"]; got != c.want {
			t.Errorf("mtu %d: the tun has %v, want %d", c.in, got, c.want)
		}
		if err := CheckConfig(cfg); err != nil {
			t.Errorf("mtu %d: sing-box rejected the config: %v", c.in, err)
		}
	}
	for _, bad := range []int{-1, 1, 575, 65536, 100000} {
		if _, _, err := singbox.Build(p.AsSlice(), singbox.Options{Mode: singbox.ModeTUN, MTU: bad}); err == nil {
			t.Errorf("mtu %d was accepted", bad)
		}
	}
}

// With IPv6 off the TUN still has its IPv6 address (so v6 traffic is caught and refused, not sent
// around the VPN), names resolve to IPv4 only, and a v6 destination is rejected before anything else.
func TestNoIPv6(t *testing.T) {
	for _, link := range testLinks() {
		p, err := importer.ParseLink(link)
		if err != nil {
			t.Fatal(err)
		}
		for _, mode := range []singbox.Mode{singbox.ModeProxy, singbox.ModeTUN} {
			on, _, err := singbox.Build(p.AsSlice(), singbox.Options{Mode: mode})
			if err != nil {
				t.Fatal(err)
			}
			off, _, err := singbox.Build(p.AsSlice(), singbox.Options{Mode: mode, NoIPv6: true})
			if err != nil {
				t.Fatal(err)
			}
			if err := CheckConfig(off); err != nil {
				t.Fatalf("%s (%s): sing-box rejected the config: %v", p.Name, mode, err)
			}
			if got := on["dns"].(map[string]any)["strategy"]; got != "prefer_ipv4" {
				t.Errorf("IPv6 on: dns strategy %v", got)
			}
			if got := off["dns"].(map[string]any)["strategy"]; got != "ipv4_only" {
				t.Errorf("IPv6 off: dns strategy %v", got)
			}
			if strings.Contains(mustJSON(t, on), `"ip_version"`) {
				t.Errorf("IPv6 on: the config refuses IPv6")
			}
			rules := off["route"].(map[string]any)["rules"].([]any)
			if len(rules) < 2 {
				t.Fatalf("rules: %v", rules)
			}
			// DNS is hijacked first (a name is still looked up), then IPv6 is refused.
			if rules[1].(map[string]any)["ip_version"] != 6 || rules[1].(map[string]any)["action"] != "reject" {
				t.Errorf("second rule is %v, want the IPv6 refusal", rules[1])
			}
			if mode == singbox.ModeTUN {
				addrs := tunOf(t, off)["address"].([]string)
				if len(addrs) != 2 {
					t.Errorf("the tun lost its IPv6 address: %v", addrs)
				}
			}
		}
	}
}

func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}
