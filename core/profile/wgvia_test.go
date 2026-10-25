package profile

import (
	"strings"
	"testing"
)

func TestWireGuardVia(t *testing.T) {
	wg := func(proto, via string) *Profile {
		return &Profile{Name: "w", Protocol: proto, Server: "203.0.113.5", Port: 51820,
			WireGuard: &WG{PrivateKey: "k", PeerPublicKey: "p", Address: []string{"10.8.0.2/32"}, Via: via}}
	}
	for name, tc := range map[string]struct {
		p    *Profile
		want string
	}{
		"none":        {wg(WireGuard, ""), ""},
		"trojan":      {wg(WireGuard, "trojan://pw@proxy.example.com:443?security=tls#p"), ""},
		"shadowsocks": {wg(WireGuard, "ss://YWVzLTEyOC1nY206cHc@proxy.example.com:8388#p"), ""},
		"hysteria2":   {wg(WireGuard, "HYSTERIA2://pw@proxy.example.com:443#p"), ""},
		"ssh":         {wg(WireGuard, "ssh://u:p@proxy.example.com:22"), "not \"ssh\""},
		"not a link":  {wg(WireGuard, "proxy.example.com"), "not \"proxy.example.com\""},
		"wireguard":   {wg(WireGuard, "wireguard://k@x.example.com:51820"), "not \"wireguard\""},
		"amneziawg":   {wg(AmneziaWG, "trojan://pw@proxy.example.com:443"), "AmneziaWG cannot be sent through a proxy"},
	} {
		t.Run(name, func(t *testing.T) {
			err := tc.p.Validate()
			switch {
			case tc.want == "" && err != nil:
				t.Fatalf("unexpected error: %v", err)
			case tc.want != "" && (err == nil || !strings.Contains(err.Error(), tc.want)):
				t.Fatalf("error = %v, want one containing %q", err, tc.want)
			}
		})
	}
}

func TestWireGuardViaEditor(t *testing.T) {
	fs, _ := FormFor(WireGuard)
	if !hasField(fs, "wireguard.via") {
		t.Error("the WireGuard editor has no proxy field")
	}
	fs, _ = FormFor(AmneziaWG)
	if hasField(fs, "wireguard.via") {
		t.Error("AmneziaWG runs on its own engine and cannot go through a proxy")
	}

	p, err := FromValues(WireGuard, map[string]string{"server": "203.0.113.5", "private_key": "k", "peer_public_key": "p",
		"address": "10.8.0.2/32", "wireguard.via": "trojan://pw@proxy.example.com:443#p"})
	if err != nil {
		t.Fatal(err)
	}
	if p.WireGuard.Via != "trojan://pw@proxy.example.com:443#p" {
		t.Fatalf("via = %q", p.WireGuard.Via)
	}
	if !codes(WarningsFor(p))[WarnWGChain] {
		t.Error("WireGuard through a proxy should carry its warning")
	}
	if !codes(WarningsFor(&Profile{Protocol: WireGuard, WireGuard: &WG{}}))[WarnDPIVisible] {
		t.Error("WireGuard is still easy to identify without a proxy")
	}
}
