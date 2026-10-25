package profile

import (
	"strings"
	"testing"
)

const dnsttKey = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"

func dnsttProfile(mutate func(*Profile)) *Profile {
	p := &Profile{Name: "d", Protocol: DNSTT, Server: "t.example.com", Port: 53, Username: "u", Password: "p",
		DNSTT: &DNSTTOpts{Domain: "t.example.com", PubKey: dnsttKey, Resolvers: []string{"udp://1.1.1.1:53", "https://dns.google/dns-query"}}}
	if mutate != nil {
		mutate(p)
	}
	return p
}

func TestDNSTTValidation(t *testing.T) {
	for name, tc := range map[string]struct {
		mutate func(*Profile)
		want   string
	}{
		"good":               {nil, ""},
		"open server":        {func(p *Profile) { p.Username, p.Password = "", "" }, ""},
		"DoT":                {func(p *Profile) { p.DNSTT.Resolvers = []string{"tls://dns.google:853"} }, ""},
		"no options":         {func(p *Profile) { p.DNSTT = nil }, "missing tunnel domain"},
		"no domain":          {func(p *Profile) { p.DNSTT.Domain = "" }, "missing tunnel domain"},
		"bad domain":         {func(p *Profile) { p.DNSTT.Domain = "not a domain!" }, "not a domain name"},
		"underscore":         {func(p *Profile) { p.DNSTT.Domain = "t_x.example.com" }, "not a domain name"},
		"short key":          {func(p *Profile) { p.DNSTT.PubKey = "00ff" }, "64 hexadecimal digits"},
		"key not hex":        {func(p *Profile) { p.DNSTT.PubKey = strings.Repeat("zz", 32) }, "64 hexadecimal digits"},
		"no resolvers":       {func(p *Profile) { p.DNSTT.Resolvers = nil }, "at least one resolver"},
		"UDP hostname":       {func(p *Profile) { p.DNSTT.Resolvers = []string{"udp://dns.google:53"} }, "must be an IP address"},
		"UDP no port":        {func(p *Profile) { p.DNSTT.Resolvers = []string{"udp://1.1.1.1"} }, "must be an IP address"},
		"DoT no port":        {func(p *Profile) { p.DNSTT.Resolvers = []string{"tls://dns.google"} }, "needs a port"},
		"plain http":         {func(p *Profile) { p.DNSTT.Resolvers = []string{"http://dns.google/dns-query"} }, "use udp://, tls:// or https://"},
		"user without pass":  {func(p *Profile) { p.Password = "" }, "both a username and a password"},
		"pass without user":  {func(p *Profile) { p.Username = "" }, "both a username and a password"},
		"server is not used": {func(p *Profile) { p.Server, p.Port = "", 0 }, ""},
	} {
		t.Run(name, func(t *testing.T) {
			err := dnsttProfile(tc.mutate).Validate()
			switch {
			case tc.want == "" && err != nil:
				t.Fatalf("unexpected error: %v", err)
			case tc.want != "" && (err == nil || !strings.Contains(err.Error(), tc.want)):
				t.Fatalf("error = %v, want one containing %q", err, tc.want)
			}
		})
	}
}

func TestDNSTTEditor(t *testing.T) {
	fs, ok := FormFor(DNSTT)
	if !ok {
		t.Fatal("no DNS tunnel editor")
	}
	keys := map[string]bool{}
	for _, f := range fs {
		keys[f.Key] = true
	}
	for _, want := range []string{"name", "dnstt.domain", "dnstt.pubkey", "dnstt.resolvers", "username", "password"} {
		if !keys[want] {
			t.Errorf("missing field %s", want)
		}
	}
	if keys["server"] || keys["port"] {
		t.Error("the tunnel is listed by its domain; it has no server and port fields")
	}

	p, err := FromValues(DNSTT, map[string]string{"dnstt.domain": "t.example.com", "dnstt.pubkey": dnsttKey,
		"dnstt.resolvers": "udp://1.1.1.1:53, https://dns.google/dns-query"})
	if err != nil {
		t.Fatal(err)
	}
	if p.Server != "t.example.com" || p.Port != 53 || p.Name != "t.example.com" {
		t.Fatalf("server = %q port = %d name = %q", p.Server, p.Port, p.Name)
	}
	if len(p.DNSTT.Resolvers) != 2 || p.DNSTT.Resolvers[1] != "https://dns.google/dns-query" {
		t.Fatalf("resolvers = %v", p.DNSTT.Resolvers)
	}
	if p.ID == "" {
		t.Error("no ID")
	}

	// The editor's default resolvers are valid ones.
	for _, f := range fs {
		if f.Key == "dnstt.resolvers" {
			for _, r := range strings.Split(f.Default, ",") {
				if err := CheckDNSTTResolver(strings.TrimSpace(r)); err != nil {
					t.Errorf("default resolver %q: %v", r, err)
				}
			}
		}
	}

	// A missing key or domain is reported as a missing field.
	if _, err := FromValues(DNSTT, map[string]string{"dnstt.domain": "t.example.com"}); err == nil {
		t.Error("a profile with no key should be refused")
	}
	// Two tunnels to the same domain with different keys are different servers.
	a := dnsttProfile(func(p *Profile) { p.ID = "" })
	b := dnsttProfile(func(p *Profile) { p.ID = ""; p.DNSTT.PubKey = strings.Repeat("11", 32) })
	a.EnsureID()
	b.EnsureID()
	if a.ID == b.ID {
		t.Error("the key is part of the identity")
	}
}

func TestDNSTTWarnings(t *testing.T) {
	if !codes(WarningsForProtocol(DNSTT))[WarnDNSTTSlow] {
		t.Error("a DNS tunnel is slow, and the protocol says so")
	}
	if codes(WarningsFor(dnsttProfile(nil)))[WarnDNSTTOpen] {
		t.Error("a login means the server is not open")
	}
	open := dnsttProfile(func(p *Profile) { p.Username, p.Password = "", "" })
	if !codes(WarningsFor(open))[WarnDNSTTOpen] {
		t.Error("no login means anyone with the link can use the server")
	}
}
