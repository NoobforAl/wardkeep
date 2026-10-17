package singbox

import "testing"

const (
	testQuad9 = "sdns://AQcAAAAAAAAADTkuOS45LjEwOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA"
	testCFDoH = "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"
	testRelay = "sdns://gREzNy4xMjAuMjE3Ljc1OjQ0Mw"
)

func TestCheckDNS(t *testing.T) {
	for _, ok := range []string{"", "1.1.1.1", "tls://9.9.9.9", "https://dns.example/dns-query", testQuad9, testCFDoH} {
		if err := CheckDNS(ok); err != nil {
			t.Errorf("CheckDNS(%q) = %v", ok, err)
		}
	}
	for _, bad := range []string{"sdns://", "sdns://AAAA", testRelay, "sdns://" + testQuad9[7:len(testQuad9)-20], "gopher://x"} {
		if err := CheckDNS(bad); err == nil {
			t.Errorf("CheckDNS(%q) accepted", bad)
		}
	}
	if err := CheckDNSRelay("203.0.113.5:4443"); err != nil {
		t.Error(err)
	}
	if err := CheckDNSRelay(testRelay); err != nil {
		t.Error(err)
	}
	for _, bad := range []string{"two words", testQuad9, "sdns://"} {
		if err := CheckDNSRelay(bad); err == nil {
			t.Errorf("CheckDNSRelay(%q) accepted", bad)
		}
	}
}

func TestDNSDescription(t *testing.T) {
	cases := []struct{ dns, relay, want string }{
		{"", "", ""},
		{"tls://1.1.1.1", "", "tls://1.1.1.1"},
		{testQuad9, "", "DNSCrypt · quad9.net"},
		{testQuad9, testRelay, "DNSCrypt · quad9.net (anonymized)"},
		{testCFDoH, testRelay, "DoH · dns.cloudflare.com"},
	}
	for _, c := range cases {
		if got := DNSDescription(c.dns, c.relay); got != c.want {
			t.Errorf("DNSDescription(%q, %q) = %q, want %q", c.dns, c.relay, got, c.want)
		}
	}
}

func TestTorKeepsOnlyDNSThatWorksThroughAnExit(t *testing.T) {
	for dns, keep := range map[string]bool{
		"https://9.9.9.9/dns-query": true,
		testCFDoH:                   true,
		testQuad9:                   true, // the forwarder uses TCP only
		"tls://1.1.1.1":             false,
		"1.1.1.1":                   false,
	} {
		o := Options{TorSocks: "127.0.0.1:1", DNS: dns}
		o.defaults()
		if (o.DNS == dns) != keep {
			t.Errorf("Tor with DNS %q: kept=%v, want %v (now %q)", dns, o.DNS == dns, keep, o.DNS)
		}
	}
}
