package dnscrypt

import (
	"bytes"
	"errors"
	"testing"

	"github.com/ameshkov/dnsstamps"
)

// Stamps copied from the public resolver and relay lists
// (https://download.dnscrypt.info/resolvers-list/v3/); what each one names is
// written in the list next to it.
const (
	stampQuad9     = "sdns://AQcAAAAAAAAADTkuOS45LjEwOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA"
	stampScaleway  = "sdns://AQcAAAAAAAAADjIxMi40Ny4yMjguMTM2IOgBuE6mBr-wusDOQ0RbsV66ZLAvo8SqMa4QY2oHkDJNHzIuZG5zY3J5cHQtY2VydC5mci5kbnNjcnlwdC5vcmc"
	stampCFDoH     = "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"
	stampAADoH     = "sdns://AgcAAAAAAAAADTIxNy4xNjkuMjAuMjIADWRucy5hYS5uZXQudWsKL2Rucy1xdWVyeQ"
	stampRelayBerl = "sdns://gREzNy4xMjAuMjE3Ljc1OjQ0Mw"
)

func TestParsePublishedDNSCryptStamps(t *testing.T) {
	st, err := ParseStamp(stampQuad9)
	if err != nil {
		t.Fatal(err)
	}
	if st.Kind != KindDNSCrypt || st.ProviderName != "2.dnscrypt-cert.quad9.net" || st.Addr != "9.9.9.10:8443" || st.Port != 8443 {
		t.Fatalf("quad9: %+v", st)
	}
	if st.Props != PropDNSSEC|PropNoLog|PropNoFilter {
		t.Errorf("quad9 properties = %b, want all three", st.Props)
	}
	if len(st.PublicKey) != 32 || st.Name() != "quad9.net" || st.HostAddr() != "9.9.9.10:8443" {
		t.Errorf("quad9 key/name/addr: %d %q %q", len(st.PublicKey), st.Name(), st.HostAddr())
	}

	// No port in the address: DNSCrypt's default, 443.
	st, err = ParseStamp(stampScaleway)
	if err != nil {
		t.Fatal(err)
	}
	if st.Addr != "212.47.228.136" || st.Port != 443 || st.HostAddr() != "212.47.228.136:443" || st.ProviderName != "2.dnscrypt-cert.fr.dnscrypt.org" {
		t.Fatalf("scaleway: %+v", st)
	}
}

func TestParsePublishedDoHStampsAndRelay(t *testing.T) {
	st, err := ParseStamp(stampCFDoH)
	if err != nil {
		t.Fatal(err)
	}
	if st.Kind != KindDoH || st.Addr != "1.0.0.1" || st.Host != "dns.cloudflare.com" || st.Path != "/dns-query" || st.Port != 443 {
		t.Fatalf("cloudflare DoH: %+v", st)
	}
	if got := st.IPs(); len(got) != 1 || got[0].String() != "1.0.0.1" {
		t.Errorf("IPs = %v", got)
	}
	if st.HostAddr() != "1.0.0.1:443" || st.Name() != "dns.cloudflare.com" {
		t.Errorf("HostAddr %q Name %q", st.HostAddr(), st.Name())
	}
	st, err = ParseStamp(stampAADoH)
	if err != nil || st.Host != "dns.aa.net.uk" || st.Addr != "217.169.20.22" {
		t.Fatalf("a-and-a: %+v %v", st, err)
	}

	relay, err := ParseStamp(stampRelayBerl)
	if err != nil {
		t.Fatal(err)
	}
	if relay.Kind != KindRelay || relay.Addr != "37.120.217.75:443" || relay.Port != 443 {
		t.Fatalf("relay: %+v", relay)
	}
	r2, err := ParseRelayStamp("203.0.113.9")
	if err != nil || r2.Addr != "203.0.113.9:443" {
		t.Fatalf("relay from a bare IP: %+v %v", r2, err)
	}
	if _, err := ParseRelayStamp(stampQuad9); err == nil {
		t.Error("a DNSCrypt stamp was accepted as a relay")
	}
	if _, err := ParseDNSCryptStamp(stampCFDoH); err == nil {
		t.Error("a DoH stamp was accepted as DNSCrypt")
	}
}

// The library knows plain, DNSCrypt and DoH: the two parsers must agree.
func TestStampsAgreeWithTheLibrary(t *testing.T) {
	for _, s := range []string{stampQuad9, stampScaleway, stampCFDoH, stampAADoH} {
		want, err := dnsstamps.NewServerStampFromString(s)
		if err != nil {
			t.Fatal(err)
		}
		got, err := ParseStamp(s)
		if err != nil {
			t.Fatal(err)
		}
		if got.Addr == "" {
			t.Fatalf("%s: no address", s)
		}
		// The library adds the default port to a bare IP; compare through HostAddr.
		if want.ServerAddrStr != got.HostAddr() {
			t.Errorf("%s: address %q, library says %q", got.Name(), got.HostAddr(), want.ServerAddrStr)
		}
		if uint64(want.Props) != uint64(got.Props) || want.Path != got.Path {
			t.Errorf("%s: props/path differ: %v %q vs %v %q", got.Name(), got.Props, got.Path, want.Props, want.Path)
		}
		if got.Kind == KindDNSCrypt && (!bytes.Equal(want.ServerPk, got.PublicKey) || want.ProviderName != got.ProviderName) {
			t.Errorf("%s: key or provider differ", got.Name())
		}
		if got.Kind == KindDoH && want.ProviderName != got.Host {
			t.Errorf("%s: host %q vs %q", got.Name(), got.Host, want.ProviderName)
		}
	}
}

func TestStampRoundTrip(t *testing.T) {
	cases := []Stamp{
		{Kind: KindDNSCrypt, Props: PropNoLog, Addr: "[2001:db8::1]:5353", PublicKey: bytes.Repeat([]byte{7}, 32), ProviderName: "2.dnscrypt-cert.example.org"},
		{Kind: KindDoH, Props: PropDNSSEC, Addr: "192.0.2.3", Host: "doh.example.org", Path: "/q", Hashes: [][]byte{{1, 2, 3}, {4, 5}}},
		{Kind: KindDoT, Addr: "192.0.2.3", Host: "dot.example.org", Port: 8853, Bootstrap: []string{"192.0.2.3", "192.0.2.4"}},
		{Kind: KindDoQ, Host: "doq.example.org"},
		{Kind: KindPlain, Addr: "192.0.2.53"},
		{Kind: KindRelay, Addr: "198.51.100.7:4443"},
	}
	for _, c := range cases {
		s := c.String()
		got, err := ParseStamp(s)
		if err != nil {
			t.Errorf("%s: %v", c.Kind, err)
			continue
		}
		if got.String() != s {
			t.Errorf("%s: re-encoding differs: %s vs %s", c.Kind, got.String(), s)
		}
		if got.Kind != c.Kind || got.Addr != c.Addr || got.Props != c.Props {
			t.Errorf("%s: fields differ: %+v vs %+v", c.Kind, got, c)
		}
	}
	// Default ports: 853 for DoT and DoQ (the library says 843 and 784), 443 for DoH, 53 plain.
	port := func(k Kind, addr, host string) int {
		st, err := ParseStamp(Stamp{Kind: k, Addr: addr, Host: host}.String())
		if err != nil {
			t.Fatal(err)
		}
		return st.Port
	}
	if p := port(KindDoT, "192.0.2.3", "dot.example.org"); p != 853 {
		t.Errorf("DoT default port = %d, want 853", p)
	}
	if p := port(KindDoQ, "", "doq.example.org"); p != 853 {
		t.Errorf("DoQ default port = %d, want 853", p)
	}
	if p := port(KindDoH, "", "doh.example.org"); p != 443 {
		t.Errorf("DoH default port = %d, want 443", p)
	}
	if p := port(KindPlain, "192.0.2.53", ""); p != 53 {
		t.Errorf("plain default port = %d, want 53", p)
	}
	// A port in the host name wins over the default.
	st, _ := ParseStamp(Stamp{Kind: KindDoH, Host: "doh.example.org:8443", Path: "/dns-query"}.String())
	if st.Port != 8443 || st.Host != "doh.example.org" {
		t.Errorf("host with port: %+v", st)
	}
}

func TestBadStampsGiveClearErrors(t *testing.T) {
	good := stampQuad9
	cases := map[string]string{
		"":                          "starts with sdns://",
		"https://1.1.1.1/dns-query": "starts with sdns://",
		"sdns://":                   "empty",
		"sdns://!!!":                "base64",
		good[:len(good)-30]:         "cut short",
		good + "AAAA":               "",              // any error is fine, but never a stamp
		"sdns://BQcAAAAAAAAAAAA":    "not supported", // type 0x05 (ODoH)
	}
	for in, want := range cases {
		_, err := ParseStamp(in)
		if err == nil {
			t.Errorf("%q was accepted", in)
			continue
		}
		if _, ok := errors.AsType[*StampError](err); !ok {
			t.Errorf("%q: error %T is not a StampError", in, err)
		}
		if want != "" && !bytes.Contains([]byte(err.Error()), []byte(want)) {
			t.Errorf("%q: error %q does not mention %q", in, err, want)
		}
	}
	// A DNSCrypt stamp with a key of the wrong length.
	bad := Stamp{Kind: KindDNSCrypt, Addr: "192.0.2.1", PublicKey: []byte{1, 2, 3}, ProviderName: "2.dnscrypt-cert.x"}.String()
	if _, err := ParseStamp(bad); err == nil || !bytes.Contains([]byte(err.Error()), []byte("32 bytes")) {
		t.Errorf("short key: %v", err)
	}
}
