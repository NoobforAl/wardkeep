package protocols

import (
	"encoding/json"
	"net/netip"
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/importer"
)

func TestTunnelAddressesInIPv6(t *testing.T) {
	for in, want := range map[string]string{
		"10.30.0.2/32": "fd30:0:0:1::2/128", "10.30.1.2/32": "fd30:0:0:1::102/128", "10.30.255.254/32": "fd30:0:0:1::fffe/128",
	} {
		got, err := WGAddress6(in)
		if err != nil || got != want {
			t.Errorf("WGAddress6(%s) = %s, %v; want %s", in, got, err, want)
		}
		a, err := AWGAddress6(in)
		if err != nil || a != strings.Replace(want, "fd30", "fd31", 1) {
			t.Errorf("AWGAddress6(%s) = %s, %v", in, a, err)
		}
	}
	for _, bad := range []string{"", "fd00::1/128", "nonsense"} {
		if _, err := WGAddress6(bad); err == nil {
			t.Errorf("WGAddress6(%q) was accepted", bad)
		}
	}
	// Every user keeps their own address, inside the server's network, never the server's own.
	seen := map[string]bool{}
	pool := netip.MustParsePrefix(WGPool6)
	for a := 0; a < 4; a++ {
		for b := 2; b < 255; b++ {
			got, _ := WGAddress6("10.30." + strconv.Itoa(a) + "." + strconv.Itoa(b) + "/32")
			p := netip.MustParsePrefix(got)
			if seen[got] || !pool.Contains(p.Addr()) || p.Addr() == netip.MustParsePrefix(wgServerAddress6).Addr() {
				t.Fatalf("10.30.%d.%d -> %s (repeated, outside the pool or the server's)", a, b, got)
			}
			seen[got] = true
		}
	}
}

// Without the setting nothing changes; with it WireGuard, AmneziaWG and OpenVPN carry the second address
// in the server's configuration and in what the user gets.
func TestIPv6InTheTunnels(t *testing.T) {
	off, on := testEnv(), testEnv()
	on.IPv6 = true
	wg, _ := Get("wireguard")
	awgp, _ := Get("amneziawg")

	for _, env := range []Env{off, on} {
		p, err := wg.Profile(env, 51820, alice)
		if err != nil {
			t.Fatal(err)
		}
		a := p.WireGuard.Address
		if env.IPv6 {
			if !slices.Equal(a, []string{"10.30.0.2/32", "fd30:0:0:1::2/128"}) {
				t.Errorf("WireGuard addresses with IPv6: %v", a)
			}
		} else if !slices.Equal(a, []string{"10.30.0.2/32"}) {
			t.Errorf("WireGuard addresses without IPv6: %v", a)
		}
		_, conf, err := wg.(FileProtocol).File(env, 51820, alice)
		if err != nil {
			t.Fatal(err)
		}
		res, err := importer.Import(conf)
		if err != nil || !slices.Equal(res.Profiles[0].WireGuard.Address, a) {
			t.Errorf("the .conf does not give back %v: %v %v", a, err, res)
		}

		ap, err := awgp.Profile(env, 51821, alice)
		if err != nil {
			t.Fatal(err)
		}
		if env.IPv6 != slices.Contains(ap.WireGuard.Address, "fd31:0:0:1::2/128") || !slices.Contains(ap.WireGuard.Address, "10.31.0.2/32") {
			t.Errorf("AmneziaWG addresses (IPv6 %v): %v", env.IPv6, ap.WireGuard.Address)
		}

		// The server's side.
		cfg := wg.Inbounds(env, 51820, []Account{alice})
		raw, _ := json.Marshal(cfg.Endpoints[0])
		var ep struct {
			Address []string `json:"address"`
			Peers   []struct {
				Allowed []string `json:"allowed_ips"`
			} `json:"peers"`
		}
		json.Unmarshal(raw, &ep)
		if env.IPv6 {
			if !slices.Equal(ep.Address, []string{"10.30.0.1/16", "fd30:0:0:1::1/64"}) || !slices.Equal(ep.Peers[0].Allowed, []string{"10.30.0.2/32", "fd30:0:0:1::2/128"}) {
				t.Errorf("WireGuard server with IPv6: %s", raw)
			}
		} else if len(ep.Address) != 1 || len(ep.Peers[0].Allowed) != 1 {
			t.Errorf("WireGuard server without IPv6: %s", raw)
		}

		for _, key := range []string{"openvpn-udp", "openvpn-tcp"} {
			o, _ := Get(key)
			raw, _ := json.Marshal(o.Inbounds(env, 1194, []Account{alice}).Endpoints[0])
			var oe struct {
				Address []string `json:"address"`
			}
			json.Unmarshal(raw, &oe)
			v6 := slices.ContainsFunc(oe.Address, func(a string) bool { return strings.Contains(a, ":") })
			if v6 != env.IPv6 || !slices.ContainsFunc(oe.Address, func(a string) bool { return strings.HasPrefix(a, "10.1") }) {
				t.Errorf("%s addresses (IPv6 %v): %v", key, env.IPv6, oe.Address)
			}
		}
	}
}
