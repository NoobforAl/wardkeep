package singbox

import (
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func wgVia(via string) *profile.Profile {
	return &profile.Profile{Name: "w", Protocol: profile.WireGuard, Server: "203.0.113.5", Port: 51820,
		WireGuard: &profile.WG{PrivateKey: "k", PeerPublicKey: "p", Address: []string{"10.8.0.2/32"}, Via: via}}
}

func TestWireGuardThroughProxyOutbound(t *testing.T) {
	ep, isEndpoint, extras, err := Outbound(wgVia("trojan://pw@proxy.example.com:443?security=tls&sni=proxy.example.com#p"), "wg1")
	if err != nil {
		t.Fatal(err)
	}
	if !isEndpoint || ep["type"] != "wireguard" {
		t.Fatalf("endpoint = %v (isEndpoint %v)", ep, isEndpoint)
	}
	if ep["detour"] != "wg1-via" {
		t.Fatalf("detour = %v", ep["detour"])
	}
	if len(extras) != 1 || extras[0]["tag"] != "wg1-via" || extras[0]["type"] != "trojan" || extras[0]["server"] != "proxy.example.com" {
		t.Fatalf("extras = %v", extras)
	}

	// A proxy that has its own helper outbound (Shadowsocks with ShadowTLS) brings it along.
	_, _, extras, err = Outbound(wgVia("ss://YWVzLTEyOC1nY206cHc@proxy.example.com:8388?plugin=shadow-tls%3Bhost%3Dwww.example.com%3Bpassword%3Dpw%3Bversion%3D3#p"), "wg2")
	if err != nil {
		t.Fatal(err)
	}
	if len(extras) != 2 {
		t.Fatalf("extras = %v", extras)
	}

	// Without a proxy nothing changes.
	ep, _, extras, err = Outbound(wgVia(""), "wg3")
	if err != nil {
		t.Fatal(err)
	}
	if _, has := ep["detour"]; has || len(extras) != 0 {
		t.Fatalf("ep = %v extras = %v", ep, extras)
	}

	for _, bad := range []string{"trojan://", "wireguard://k@x.example.com:51820", "ssh://u:p@proxy.example.com:22"} {
		if _, _, _, err := Outbound(wgVia(bad), "wg4"); err == nil || !strings.Contains(err.Error(), "under WireGuard") {
			t.Errorf("%q: error = %v", bad, err)
		}
	}
}
