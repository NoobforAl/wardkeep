package singbox

import (
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func TestMultiplexOutbound(t *testing.T) {
	mux := &profile.Mux{Protocol: "yamux", Padding: true, MaxConnections: 4, MinStreams: 8}
	for _, p := range []*profile.Profile{
		{Protocol: profile.Trojan, Server: "a.example", Port: 443, Password: "pw", TLS: &profile.TLS{Enabled: true}, Multiplex: mux},
		{Protocol: profile.VLESS, Server: "a.example", Port: 443, UUID: "u", Multiplex: mux},
		{Protocol: profile.VMess, Server: "a.example", Port: 443, UUID: "u", Multiplex: mux},
		{Protocol: profile.Shadowsocks, Server: "a.example", Port: 8388, Method: "aes-128-gcm", Password: "pw", Multiplex: mux},
	} {
		out, _, _, err := Outbound(p, "t")
		if err != nil {
			t.Fatalf("%s: %v", p.Protocol, err)
		}
		m, ok := out["multiplex"].(obj)
		if !ok {
			t.Fatalf("%s: no multiplex in %v", p.Protocol, out)
		}
		if m["enabled"] != true || m["protocol"] != "yamux" || m["padding"] != true || m["max_connections"] != 4 || m["min_streams"] != 8 {
			t.Errorf("%s: multiplex = %v", p.Protocol, m)
		}
		if _, has := m["max_streams"]; has {
			t.Errorf("%s: max_streams should be left out when zero: %v", p.Protocol, m)
		}
	}

	off := &profile.Profile{Protocol: profile.Trojan, Server: "a.example", Port: 443, Password: "pw", Multiplex: &profile.Mux{}}
	out, _, _, err := Outbound(off, "t")
	if err != nil {
		t.Fatal(err)
	}
	if _, has := out["multiplex"]; has {
		t.Errorf("an empty multiplexing should leave the outbound alone: %v", out)
	}
}
