package manager

import (
	"errors"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/server/store"
)

// The DNS tunnel is off for a new server, has a key at once, and cannot be switched on before it has a domain.
func TestDNSTTNeedsADomain(t *testing.T) {
	m := newManager(t)
	info, err := m.DNSTT()
	if err != nil {
		t.Fatal(err)
	}
	if info.Enabled || info.Domain != "" || len(info.PublicKey) != 64 || len(info.Records) != 0 {
		t.Fatalf("a new server's tunnel: %+v", info)
	}
	on := true
	if _, err := m.SetProtocol(store.DNSTTKey, ProtocolPatch{Enabled: &on}); !errors.Is(err, ErrInvalid) || !strings.Contains(err.Error(), "domain") {
		t.Fatalf("enabling without a domain: %v", err)
	}

	for _, bad := range []string{"", "localhost", "t..example.com", "-t.example.com", "t_x.example.com", "not a domain", strings.Repeat("a", 64) + ".example.com"} {
		if _, err := m.SetDNSTTDomain(bad); !errors.Is(err, ErrInvalid) {
			t.Errorf("%q should be refused, got %v", bad, err)
		}
	}
	info, err = m.SetDNSTTDomain("  T.Example.COM. ")
	if err != nil || info.Domain != "t.example.com" {
		t.Fatalf("set: %+v %v", info, err)
	}
	if _, err := m.SetProtocol(store.DNSTTKey, ProtocolPatch{Enabled: &on}); err != nil {
		t.Fatalf("enabling with a domain: %v", err)
	}
}

// The two records the operator has to create delegate the zone to the server.
func TestDNSTTRecords(t *testing.T) {
	cases := map[string]struct {
		domain, host string
		want         []DNSRecord
	}{
		"IPv4": {"t.example.com", "203.0.113.7", []DNSRecord{{"t.example.com", "NS", "tns.example.com"}, {"tns.example.com", "A", "203.0.113.7"}}},
		"IPv6": {"t.example.com", "2001:db8::7", []DNSRecord{{"t.example.com", "NS", "tns.example.com"}, {"tns.example.com", "AAAA", "2001:db8::7"}}},
		"name": {"t.example.com", "vpn.example.com", []DNSRecord{{"t.example.com", "NS", "vpn.example.com"}}},
		"none": {"", "203.0.113.7", nil},
		"deep": {"x.t.example.com", "203.0.113.7", []DNSRecord{{"x.t.example.com", "NS", "tns.t.example.com"}, {"tns.t.example.com", "A", "203.0.113.7"}}},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			got := dnsttRecords(c.domain, c.host)
			if len(got) != len(c.want) {
				t.Fatalf("records = %v, want %v", got, c.want)
			}
			for i := range got {
				if got[i] != c.want[i] {
					t.Fatalf("records = %v, want %v", got, c.want)
				}
			}
		})
	}
}

// The user's link carries the domain, the key and their login, and nothing is handed out before there is a domain.
func TestDNSTTLinkForAUser(t *testing.T) {
	m := newManager(t)
	if _, err := m.AddUser(NewUser{Name: "alice"}); err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetDNSTTDomain("t.example.com"); err != nil {
		t.Fatal(err)
	}
	on := true
	if _, err := m.SetProtocol(store.DNSTTKey, ProtocolPatch{Enabled: &on}); err != nil {
		t.Fatal(err)
	}
	info, _ := m.DNSTT()
	set, err := m.Links("alice")
	if err != nil {
		t.Fatal(err)
	}
	var link string
	for _, l := range set.Links {
		if l.Protocol == store.DNSTTKey {
			link = l.URL
		}
	}
	if link == "" {
		t.Fatalf("no dnstt link in %+v", set.Links)
	}
	p, err := importer.ParseLink(link)
	if err != nil {
		t.Fatal(err)
	}
	if p.Protocol != profile.DNSTT || p.DNSTT.Domain != "t.example.com" || p.DNSTT.PubKey != info.PublicKey || p.Username != "alice" || p.Password == "" {
		t.Fatalf("link = %q profile = %+v %+v", link, p, p.DNSTT)
	}

	// A new key means a new link.
	rotated, err := m.RotateDNSTTKey()
	if err != nil {
		t.Fatal(err)
	}
	if rotated.PublicKey == info.PublicKey || rotated.Domain != "t.example.com" || len(rotated.Records) != 2 {
		t.Fatalf("after rotating: %+v", rotated)
	}
}

// A server made before the tunnel existed gets its key when it is loaded.
func TestOldServerGetsADNSTTKey(t *testing.T) {
	m := newManager(t)
	if err := m.Store.Update(func(st *store.State) error { st.Server.DNSTT = store.DNSTT{Domain: "t.example.com"}; return nil }); err != nil {
		t.Fatal(err)
	}
	info, err := m.DNSTT()
	if err != nil {
		t.Fatal(err)
	}
	if len(info.PublicKey) != 64 || info.Domain != "t.example.com" {
		t.Fatalf("%+v", info)
	}
}
