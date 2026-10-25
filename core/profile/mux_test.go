package profile

import (
	"strings"
	"testing"
)

func TestMuxValidation(t *testing.T) {
	trojan := func(m *Mux) *Profile {
		return &Profile{Name: "t", Protocol: Trojan, Server: "a.example", Port: 443, Password: "pw", Multiplex: m}
	}
	for name, tc := range map[string]struct {
		p    *Profile
		want string // part of the error; empty = valid
	}{
		"off":              {trojan(nil), ""},
		"empty is off":     {trojan(&Mux{}), ""},
		"smux":             {trojan(&Mux{Protocol: "smux", Padding: true}), ""},
		"counts":           {trojan(&Mux{Protocol: "yamux", MaxConnections: 4, MinStreams: 8}), ""},
		"max streams":      {trojan(&Mux{Protocol: "h2mux", MaxStreams: 16}), ""},
		"unknown":          {trojan(&Mux{Protocol: "quic"}), "unknown multiplexing protocol"},
		"negative":         {trojan(&Mux{Protocol: "smux", MinStreams: -1}), "cannot be negative"},
		"streams conflict": {trojan(&Mux{Protocol: "smux", MaxStreams: 4, MaxConnections: 2}), "cannot be combined"},
		"wrong protocol": {&Profile{Name: "h", Protocol: Hysteria2, Server: "a.example", Port: 443, Password: "pw",
			Multiplex: &Mux{Protocol: "smux"}}, "not available for hysteria2"},
		"vision": {&Profile{Name: "v", Protocol: VLESS, Server: "a.example", Port: 443, UUID: "u", Flow: "xtls-rprx-vision",
			Multiplex: &Mux{Protocol: "smux"}}, "VLESS flow"},
		"vless without flow": {&Profile{Name: "v", Protocol: VLESS, Server: "a.example", Port: 443, UUID: "u",
			Multiplex: &Mux{Protocol: "smux"}}, ""},
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

func TestMuxEditor(t *testing.T) {
	p, err := FromValues(Trojan, map[string]string{"server": "a.example", "password": "pw",
		"mux.protocol": "smux", "mux.padding": "true", "mux.max_connections": "4"})
	if err != nil {
		t.Fatal(err)
	}
	if m := p.Multiplex; m == nil || m.Protocol != "smux" || !m.Padding || m.MaxConnections != 4 {
		t.Fatalf("multiplex = %+v", m)
	}
	if !codes(WarningsFor(p))[WarnMuxLossy] {
		t.Error("multiplexing should carry its info warning")
	}

	// Switching it off in the editor leaves no empty multiplexing behind.
	vals := p.Values()
	vals["mux.protocol"] = ""
	if err := p.Apply(vals); err != nil {
		t.Fatal(err)
	}
	if p.Multiplex != nil {
		t.Errorf("multiplexing should be gone, got %+v", p.Multiplex)
	}

	// Every protocol that can multiplex has the fields; the others do not.
	for _, proto := range []string{VLESS, VMess, Trojan, Shadowsocks} {
		fs, _ := FormFor(proto)
		if !hasField(fs, "mux.protocol") {
			t.Errorf("%s has no multiplexing field", proto)
		}
	}
	for _, proto := range []string{Hysteria2, TUIC, WireGuard, SSH} {
		fs, _ := FormFor(proto)
		if hasField(fs, "mux.protocol") {
			t.Errorf("%s should not offer multiplexing", proto)
		}
	}
}

func hasField(fs []Field, key string) bool {
	for _, f := range fs {
		if f.Key == key {
			return true
		}
	}
	return false
}
