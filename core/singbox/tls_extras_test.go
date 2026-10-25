package singbox

import (
	"reflect"
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func TestTLSExtrasOutbound(t *testing.T) {
	p := &profile.Profile{Protocol: profile.Trojan, Server: "a.example", Port: 443, Password: "pw",
		TLS: &profile.TLS{Enabled: true, Fragment: true, RecordFragment: true,
			ECH: &profile.ECH{Enabled: true, Config: "-----BEGIN ECH CONFIGS-----\r\nAEX+DQBB\r\n-----END ECH CONFIGS-----", QueryServerName: "public.example"}}}
	out, _, _, err := Outbound(p, "t")
	if err != nil {
		t.Fatal(err)
	}
	tls := out["tls"].(obj)
	if tls["fragment"] != true || tls["record_fragment"] != true {
		t.Errorf("tls = %v", tls)
	}
	ech := tls["ech"].(obj)
	wantConfig := []string{"-----BEGIN ECH CONFIGS-----", "AEX+DQBB", "-----END ECH CONFIGS-----"}
	if ech["enabled"] != true || !reflect.DeepEqual(ech["config"], wantConfig) || ech["query_server_name"] != "public.example" {
		t.Errorf("ech = %v", ech)
	}

	plain := &profile.Profile{Protocol: profile.Trojan, Server: "a.example", Port: 443, Password: "pw",
		TLS: &profile.TLS{Enabled: true, ECH: &profile.ECH{Config: "junk"}}}
	out, _, _, err = Outbound(plain, "t")
	if err != nil {
		t.Fatal(err)
	}
	tls = out["tls"].(obj)
	for _, k := range []string{"fragment", "record_fragment", "ech"} {
		if _, has := tls[k]; has {
			t.Errorf("%s should be left out: %v", k, tls)
		}
	}
}
