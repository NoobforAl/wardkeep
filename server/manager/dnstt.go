package manager

import (
	"net"
	"strings"

	"github.com/NoobforAl/omnitun/server/store"
)

// DNSTTInfo describes the server's optional DNS tunnel.
type DNSTTInfo struct {
	Enabled bool `json:"enabled"`
	Port    int  `json:"port"`
	// Domain is the zone delegated to the server; empty until set.
	Domain    string `json:"domain,omitempty" doc:"The DNS zone delegated to this server, such as t.example.com"`
	PublicKey string `json:"public_key" doc:"The server's public key (64 hex digits), in every user's link"`
	// Records are the two DNS records to create at the zone's provider, empty until the domain is set.
	Records []DNSRecord `json:"records,omitempty" doc:"The DNS records that delegate the zone to this server"`
}

// DNSRecord is one DNS record to create.
type DNSRecord struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Value string `json:"value"`
}

// dnsttRecords are the two records that hand a zone to the server: an NS record for the tunnel's domain naming a
// host, and an address record for that host, which sits next to the domain in the parent zone.
func dnsttRecords(domain, host string) []DNSRecord {
	if domain == "" {
		return nil
	}
	_, parent, _ := strings.Cut(domain, ".")
	ns := "tns." + parent
	typ := "A"
	if ip := net.ParseIP(host); ip != nil && ip.To4() == nil {
		typ = "AAAA"
	}
	if net.ParseIP(host) == nil {
		// A server named by a domain already has an address record; the NS record can point at it.
		return []DNSRecord{{Name: domain, Type: "NS", Value: host}}
	}
	return []DNSRecord{
		{Name: domain, Type: "NS", Value: ns},
		{Name: ns, Type: typ, Value: host},
	}
}

func dnsttInfo(st *store.State) *DNSTTInfo {
	p := st.Server.Protocols[store.DNSTTKey]
	d := st.Server.DNSTT
	info := &DNSTTInfo{Domain: d.Domain, PublicKey: d.PublicKey, Records: dnsttRecords(d.Domain, st.Server.PublicHost)}
	if p != nil {
		info.Enabled, info.Port = p.Enabled, p.Port
	}
	return info
}

// DNSTT returns the state of the DNS tunnel.
func (m *Manager) DNSTT() (*DNSTTInfo, error) {
	st, err := m.Store.Load()
	if err != nil {
		return nil, err
	}
	return dnsttInfo(st), nil
}

// SetDNSTTDomain sets the zone delegated to the server. Users' links carry it, so changing it means new links.
func (m *Manager) SetDNSTTDomain(domain string) (*DNSTTInfo, error) {
	d, err := store.CheckDNSTTDomain(domain)
	if err != nil {
		return nil, invalid("%v", err)
	}
	var out *DNSTTInfo
	err = m.Store.Update(func(st *store.State) error {
		st.Server.DNSTT.Domain = d
		out = dnsttInfo(st)
		return nil
	})
	return out, err
}

// RotateDNSTTKey makes a new key pair; every user needs the new link.
func (m *Manager) RotateDNSTTKey() (*DNSTTInfo, error) {
	var out *DNSTTInfo
	err := m.Store.Update(func(st *store.State) error {
		if err := st.RotateDNSTTKey(); err != nil {
			return err
		}
		out = dnsttInfo(st)
		return nil
	})
	return out, err
}
