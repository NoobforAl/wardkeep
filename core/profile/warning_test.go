package profile

import "testing"

func codes(ws []Warning) map[string]bool {
	m := map[string]bool{}
	for _, w := range ws {
		m[w.Code] = true
	}
	return m
}

func TestWarningsForProtocols(t *testing.T) {
	want := map[string]string{
		VMess: WarnVMessLegacy, Shadowsocks: WarnSSPlain, Hysteria: WarnHysteria1,
		WireGuard: WarnDPIVisible, OpenVPN: WarnDPIVisible,
		SSH: WarnSSHVisible,
	}
	for proto, code := range want {
		if !codes(WarningsForProtocol(proto))[code] {
			t.Errorf("%s: missing warning %s", proto, code)
		}
	}
	for _, proto := range []string{VLESS, Trojan, Hysteria2, TUIC, AnyTLS, Naive, AmneziaWG, Tor, Tailscale} {
		if ws := WarningsForProtocol(proto); len(ws) != 0 {
			t.Errorf("%s: unexpected warnings %v", proto, ws)
		}
	}
}

func TestFormsCarryWarnings(t *testing.T) {
	for _, f := range Forms() {
		if got, want := len(f.Warnings), len(WarningsForProtocol(f.Protocol)); got != want {
			t.Errorf("%s: form has %d warnings, want %d", f.Protocol, got, want)
		}
	}
}

func TestWarningsForProfile(t *testing.T) {
	clean := &Profile{Protocol: VLESS, Server: "a.example", Port: 443, UUID: "u",
		TLS: &TLS{Enabled: true, Reality: &Reality{PublicKey: "k"}}}
	if ws := WarningsFor(clean); len(ws) != 0 {
		t.Errorf("a VLESS+Reality profile should have no warnings, got %v", ws)
	}

	insecure := &Profile{Protocol: Trojan, TLS: &TLS{Enabled: true, Insecure: true}}
	if !codes(WarningsFor(insecure))[WarnTLSInsecure] {
		t.Error("insecure TLS should warn")
	}

	for _, p := range []*Profile{
		{Protocol: VLESS},
		{Protocol: VMess, TLS: &TLS{}},
		{Protocol: Trojan, TLS: &TLS{Enabled: false}},
	} {
		if !codes(WarningsFor(p))[WarnNoTLS] {
			t.Errorf("%s without TLS should warn", p.Protocol)
		}
	}

	plain := &Profile{Protocol: Shadowsocks}
	if !codes(WarningsFor(plain))[WarnSSPlain] {
		t.Error("plain Shadowsocks should warn")
	}
	plugged := &Profile{Protocol: Shadowsocks, Plugin: "shadow-tls"}
	if codes(WarningsFor(plugged))[WarnSSPlain] {
		t.Error("Shadowsocks with a plugin should not warn about random-looking bytes")
	}

	if ws := WarningsFor(&Profile{Protocol: VMess}); len(codes(ws)) != len(ws) {
		t.Errorf("warnings repeat a code: %v", ws)
	}
	if WarningsFor(nil) != nil {
		t.Error("nil profile should have no warnings")
	}
}

func TestInsecureFieldHasAWarning(t *testing.T) {
	fs, _ := FormFor(Trojan)
	for _, f := range fs {
		if f.Key == "tls.insecure" {
			if f.Warning == nil || f.Warning.Code != WarnTLSInsecure {
				t.Errorf("tls.insecure should carry %s, got %v", WarnTLSInsecure, f.Warning)
			}
			return
		}
	}
	t.Error("Trojan form has no tls.insecure field")
}

func TestWarningTextsAreSet(t *testing.T) {
	for _, w := range []Warning{wInsecure, wNoTLS, wVMess, wSSPlain, wHysteria1, wDPI, wSSH, wDNSTTSlow, wDNSTTOpen,
		wMux, wFragment, wECH, wWGChain, wUnsignedSub} {
		if w.Code == "" || w.Text == "" || (w.Level != WarnRisk && w.Level != WarnInfo) {
			t.Errorf("incomplete warning %+v", w)
		}
	}
}
