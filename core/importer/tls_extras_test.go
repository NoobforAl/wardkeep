package importer

import (
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

const testECHPEM = "-----BEGIN ECH CONFIGS-----\nAEX+DQBB\n-----END ECH CONFIGS-----"

func TestTLSExtrasFromLinks(t *testing.T) {
	const uuid = "b831381d-6324-4d53-ad4f-8cda48b30811"
	p, err := ParseLink("trojan://pw@example.com:443?security=tls&tlsfrag=1&recfrag=1&ech=AEX%2BDQBB&echsni=public.example#t")
	if err != nil {
		t.Fatal(err)
	}
	if !p.TLS.Fragment || !p.TLS.RecordFragment || p.TLS.ECH == nil || p.TLS.ECH.Config != testECHPEM || p.TLS.ECH.QueryServerName != "public.example" {
		t.Fatalf("tls = %+v ech = %+v", p.TLS, p.TLS.ECH)
	}

	// ech=1 means "look the configuration up in DNS".
	p, err = ParseLink("vless://" + uuid + "@example.com:443?security=tls&ech=1#v")
	if err != nil {
		t.Fatal(err)
	}
	if !p.TLS.ECH.On() || p.TLS.ECH.Config != "" {
		t.Fatalf("ech = %+v", p.TLS.ECH)
	}

	// Reality and ECH exclude each other: the server stays, the option goes; fragmenting is fine with Reality.
	p, err = ParseLink("vless://" + uuid + "@example.com:443?security=reality&pbk=k&ech=1&tlsfrag=1#v")
	if err != nil {
		t.Fatal(err)
	}
	if p.TLS.ECH != nil || !p.TLS.Fragment {
		t.Fatalf("tls = %+v ech = %+v", p.TLS, p.TLS.ECH)
	}

	p, err = ParseLink("anytls://pw@example.com:443/?sni=example.com&tlsfrag=1&ech=AEX%2BDQBB#a")
	if err != nil {
		t.Fatal(err)
	}
	if !p.TLS.Fragment || !p.TLS.ECH.On() {
		t.Fatalf("tls = %+v ech = %+v", p.TLS, p.TLS.ECH)
	}

	// A QUIC protocol ignores the options (its link parser does not read them).
	p, err = ParseLink("hysteria2://pw@example.com:443?sni=example.com&tlsfrag=1&ech=1#h")
	if err != nil {
		t.Fatal(err)
	}
	if p.TLS.Fragment || p.TLS.ECH != nil {
		t.Fatalf("hysteria2 should not carry handshake options: %+v", p.TLS)
	}
}

func TestTLSExtrasFromJSONAndClash(t *testing.T) {
	res, err := Import(`{"outbounds": [
	  {"type": "trojan", "tag": "a", "server": "a.example.com", "server_port": 443, "password": "pw",
	   "tls": {"enabled": true, "fragment": true, "record_fragment": true,
	           "ech": {"enabled": true, "config": ["-----BEGIN ECH CONFIGS-----", "AEX+DQBB", "-----END ECH CONFIGS-----"], "query_server_name": "public.example"}}},
	  {"type": "hysteria2", "tag": "h", "server": "h.example.com", "server_port": 443, "password": "pw",
	   "tls": {"enabled": true, "fragment": true, "ech": {"enabled": true}}}
	]}`)
	if err != nil {
		t.Fatal(err)
	}
	a, h := res.Profiles[0], res.Profiles[1]
	if !a.TLS.Fragment || !a.TLS.RecordFragment || a.TLS.ECH == nil || a.TLS.ECH.Config != testECHPEM || a.TLS.ECH.QueryServerName != "public.example" {
		t.Fatalf("trojan tls = %+v ech = %+v", a.TLS, a.TLS.ECH)
	}
	if h.TLS.Fragment || h.TLS.ECH != nil {
		t.Fatalf("hysteria2 should lose the options: %+v", h.TLS)
	}

	res, err = Import(`proxies:
  - {name: a, type: trojan, server: a.example.com, port: 443, password: pw, ech-opts: {enable: true, config: AEX+DQBB, query-server-name: public.example}}
  - {name: h, type: hysteria2, server: h.example.com, port: 443, password: pw, ech-opts: {enable: true}}
`)
	if err != nil {
		t.Fatal(err)
	}
	a, h = res.Profiles[0], res.Profiles[1]
	if a.TLS.ECH == nil || a.TLS.ECH.Config != testECHPEM || a.TLS.ECH.QueryServerName != "public.example" {
		t.Fatalf("clash trojan ech = %+v", a.TLS.ECH)
	}
	if h.TLS.ECH != nil {
		t.Fatalf("clash hysteria2 should lose ECH: %+v", h.TLS.ECH)
	}
	_ = profile.Trojan
}
