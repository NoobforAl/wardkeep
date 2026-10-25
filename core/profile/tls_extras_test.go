package profile

import (
	"strings"
	"testing"
)

const testECH = "-----BEGIN ECH CONFIGS-----\nAEX+DQBB\n-----END ECH CONFIGS-----"

func TestTLSExtrasValidation(t *testing.T) {
	trojan := func(t *TLS) *Profile {
		return &Profile{Name: "t", Protocol: Trojan, Server: "a.example", Port: 443, Password: "pw", TLS: t}
	}
	for name, tc := range map[string]struct {
		p    *Profile
		want string // part of the error; empty = valid
	}{
		"fragment":         {trojan(&TLS{Enabled: true, Fragment: true, RecordFragment: true}), ""},
		"ech in DNS":       {trojan(&TLS{Enabled: true, ECH: &ECH{Enabled: true}}), ""},
		"ech with config":  {trojan(&TLS{Enabled: true, ECH: &ECH{Enabled: true, Config: testECH}}), ""},
		"ech switched off": {trojan(&TLS{Enabled: true, ECH: &ECH{Config: "junk"}}), ""},
		"fragment and reality": {&Profile{Name: "v", Protocol: VLESS, Server: "a.example", Port: 443, UUID: "u",
			TLS: &TLS{Enabled: true, Fragment: true, Reality: &Reality{PublicKey: "k"}}}, ""},
		"ech and reality": {&Profile{Name: "v", Protocol: VLESS, Server: "a.example", Port: 443, UUID: "u",
			TLS: &TLS{Enabled: true, ECH: &ECH{Enabled: true}, Reality: &Reality{PublicKey: "k"}}}, "cannot be used with Reality"},
		"fragment without tls": {trojan(&TLS{Fragment: true}), "needs TLS"},
		"ech without tls":      {trojan(&TLS{ECH: &ECH{Enabled: true}}), "ECH needs TLS"},
		"bad ech config":       {trojan(&TLS{Enabled: true, ECH: &ECH{Enabled: true, Config: "AEX+DQBB"}}), "ECH CONFIGS"},
		"quic protocol": {&Profile{Name: "h", Protocol: Hysteria2, Server: "a.example", Port: 443, Password: "pw",
			TLS: &TLS{Enabled: true, Fragment: true}}, "not available for hysteria2"},
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

func TestTLSExtrasEditor(t *testing.T) {
	p, err := FromValues(AnyTLS, map[string]string{"server": "a.example", "password": "pw",
		"tls.fragment": "true", "tls.record_fragment": "true", "tls.ech": "true", "tls.ech_config": testECH, "tls.ech_query_name": "public.example"})
	if err != nil {
		t.Fatal(err)
	}
	if !p.TLS.Fragment || !p.TLS.RecordFragment || !p.TLS.ECH.On() || p.TLS.ECH.Config != testECH || p.TLS.ECH.QueryServerName != "public.example" {
		t.Fatalf("tls = %+v ech = %+v", p.TLS, p.TLS.ECH)
	}
	got := codes(WarningsFor(p))
	if !got[WarnFragmentSide] || !got[WarnECHServer] {
		t.Errorf("warnings = %v", got)
	}

	// Switching ECH off leaves nothing behind, and the other options stay.
	vals := p.Values()
	vals["tls.ech"], vals["tls.ech_config"], vals["tls.ech_query_name"] = "false", "", ""
	if err := p.Apply(vals); err != nil {
		t.Fatal(err)
	}
	if p.TLS.ECH != nil || !p.TLS.Fragment {
		t.Errorf("after switching ECH off: tls = %+v ech = %+v", p.TLS, p.TLS.ECH)
	}

	for _, proto := range []string{VLESS, VMess, Trojan, AnyTLS} {
		fs, _ := FormFor(proto)
		if !hasField(fs, "tls.fragment") || !hasField(fs, "tls.ech") {
			t.Errorf("%s has no handshake options", proto)
		}
	}
	for _, proto := range []string{Hysteria2, TUIC, Naive, Shadowsocks} {
		fs, _ := FormFor(proto)
		if hasField(fs, "tls.fragment") || hasField(fs, "tls.ech") {
			t.Errorf("%s should not offer handshake options", proto)
		}
	}
}

func TestECHPEM(t *testing.T) {
	if got := ECHBase64(testECH); got != "AEX+DQBB" {
		t.Errorf("ECHBase64 = %q", got)
	}
	if got := ECHPEM("AEX+DQBB"); got != testECH {
		t.Errorf("ECHPEM = %q", got)
	}
	if got := ECHPEM(testECH); got != testECH {
		t.Errorf("a PEM block should come back as it is, got %q", got)
	}
	if got := ECHPEM("not base64!"); got != "" {
		t.Errorf("junk should give nothing, got %q", got)
	}
	long := strings.Repeat("A", 152)
	pem := ECHPEM(long)
	for _, line := range strings.Split(pem, "\n") {
		if len(line) > 64 && !strings.HasPrefix(line, "-----") {
			t.Errorf("line longer than 64: %q", line)
		}
	}
	if ECHBase64(pem) != long {
		t.Error("the body changed through PEM and back")
	}
}
