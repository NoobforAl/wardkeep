package singbox

import (
	"testing"

	"github.com/NoobforAl/wardkeep/core/profile"
)

func TestTorProfileRoutesIntoSocks(t *testing.T) {
	p := &profile.Profile{Name: "Tor", Protocol: profile.Tor, Tor: &profile.TorOpts{}}
	p.EnsureID()
	if _, skipped, err := Build([]*profile.Profile{p}, Options{}); err == nil || len(skipped) != 1 {
		t.Fatalf("without a Tor client the profile should be skipped: err=%v skipped=%v", err, skipped)
	}
	cfg, skipped, err := Build([]*profile.Profile{p}, Options{TorSocks: "127.0.0.1:9150", Selected: p.ID})
	if err != nil || len(skipped) != 0 {
		t.Fatalf("err=%v skipped=%v", err, skipped)
	}
	var found obj
	for _, o := range cfg["outbounds"].([]any) {
		if m, ok := o.(obj); ok && m["tag"] == p.ID {
			found = m
		}
	}
	if found["type"] != "socks" || found["server"] != "127.0.0.1" || found["server_port"] != 9150 {
		t.Fatalf("outbound = %v", found)
	}
}

func TestTorForcesHTTPSDNS(t *testing.T) {
	o := Options{TorSocks: "127.0.0.1:1", DNS: "tls://1.1.1.1"}
	o.defaults()
	if o.DNS != "https://1.1.1.1/dns-query" {
		t.Fatalf("DNS = %q", o.DNS)
	}
	o = Options{DNS: "tls://1.1.1.1"}
	o.defaults()
	if o.DNS != "tls://1.1.1.1" {
		t.Fatalf("DNS changed without Tor: %q", o.DNS)
	}
}

func TestTorTunUsesGvisorStack(t *testing.T) {
	p := &profile.Profile{Name: "Tor", Protocol: profile.Tor, Tor: &profile.TorOpts{}}
	p.EnsureID()
	cfg, _, err := Build([]*profile.Profile{p}, Options{Mode: ModeTUN, TorSocks: "127.0.0.1:9150", Selected: p.ID})
	if err != nil {
		t.Fatal(err)
	}
	tun := cfg["inbounds"].([]any)[0].(obj)
	if tun["stack"] != "gvisor" {
		t.Fatalf("stack = %v", tun["stack"])
	}
}

// A helper that runs as this app (rVPN) keeps the app out of the VPN, so the TUN must not answer apps' TCP through
// a listener in this app either: their connections would bypass the tunnel.
func TestSelfExcludedTunUsesGvisorStack(t *testing.T) {
	p := &profile.Profile{Name: "v", Protocol: profile.VLESS, Server: "example.com", Port: 443, UUID: "b831381d-6324-4d53-ad4f-8cda48b30811"}
	p.EnsureID()
	for _, tc := range []struct {
		exclude []string
		want    string
	}{{[]string{SelfPackage}, "gvisor"}, {[]string{"com.example.other"}, "mixed"}, {nil, "mixed"}} {
		cfg, _, err := Build([]*profile.Profile{p}, Options{Mode: ModeTUN, ExcludePackages: tc.exclude, Selected: p.ID})
		if err != nil {
			t.Fatal(err)
		}
		if tun := cfg["inbounds"].([]any)[0].(obj); tun["stack"] != tc.want {
			t.Errorf("exclude %v: stack = %v, want %s", tc.exclude, tun["stack"], tc.want)
		}
	}
}

// With a TCP-only helper selected, UDP is refused outright (after DNS), so apps fall back to TCP at once instead
// of waiting on packets the helper drops; other selections keep UDP.
func TestTCPOnlyHelperRejectsUDP(t *testing.T) {
	r := &profile.Profile{ID: "r", Name: "r", Protocol: profile.RVPN, Server: "vpn.example.org", Port: 443}
	v := &profile.Profile{ID: "v", Name: "v", Protocol: profile.VLESS, Server: "example.com", Port: 443, UUID: "b831381d-6324-4d53-ad4f-8cda48b30811"}
	helpers := map[string]HelperSocks{"r": {Addr: "127.0.0.1:1080"}}
	for _, tc := range []struct {
		selected string
		want     bool
	}{{"r", true}, {"v", false}} {
		cfg, _, err := Build([]*profile.Profile{r, v}, Options{Mode: ModeTUN, Helpers: helpers, Selected: tc.selected})
		if err != nil {
			t.Fatal(err)
		}
		rules := cfg["route"].(obj)["rules"].([]any)
		got := false
		for i, rule := range rules {
			m := rule.(obj)
			if m["network"] == "udp" && m["action"] == "reject" {
				got = true
				if i == 0 {
					t.Error("UDP is refused before DNS is caught")
				}
			}
		}
		if got != tc.want {
			t.Errorf("selected %s: UDP rejected = %v, want %v", tc.selected, got, tc.want)
		}
	}
}
