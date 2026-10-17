package manager

import (
	"net"
	"strings"

	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/store"
)

// DNSCryptInfo describes the server's optional DNSCrypt resolver.
type DNSCryptInfo struct {
	Enabled      bool   `json:"enabled"`
	Port         int    `json:"port"`
	ProviderName string `json:"provider_name"`
	PublicKey    string `json:"public_key" doc:"Ed25519 key of the provider (hex), the one in the stamp"`
	Upstream     string `json:"upstream,omitempty" doc:"Resolver the server asks; empty = the host's own"`
	Stamp        string `json:"stamp,omitempty" doc:"DNS stamp (sdns://...) to give to clients; empty while the resolver is off"`
}

func dnsCryptInfo(st *store.State) *DNSCryptInfo {
	p := st.Server.Protocols[store.DNSCryptKey]
	d := st.Server.DNSCrypt
	info := &DNSCryptInfo{ProviderName: d.ProviderName, PublicKey: d.PublicKey, Upstream: d.Upstream}
	if p != nil {
		info.Enabled, info.Port = p.Enabled, p.Port
	}
	if stamp, err := serverconf.DNSCryptStamp(st); err == nil {
		info.Stamp = stamp
	}
	return info
}

// DNSCrypt returns the state of the DNSCrypt resolver.
func (m *Manager) DNSCrypt() (*DNSCryptInfo, error) {
	st, err := m.Store.Load()
	if err != nil {
		return nil, err
	}
	return dnsCryptInfo(st), nil
}

// DNSCryptStamp returns the resolver's DNS stamp; it fails while the resolver is off.
func (m *Manager) DNSCryptStamp() (string, error) {
	st, err := m.Store.Load()
	if err != nil {
		return "", err
	}
	s, err := serverconf.DNSCryptStamp(st)
	if err != nil {
		return "", invalid("%v", err)
	}
	return s, nil
}

// RotateDNSCryptKey replaces the resolver's long-term key, which changes its
// stamp. A running server uses the new key after its next start; clients must
// take the new stamp.
func (m *Manager) RotateDNSCryptKey() (*DNSCryptInfo, error) {
	var out *DNSCryptInfo
	err := m.Store.Update(func(st *store.State) error {
		if err := st.RotateDNSCryptKey(); err != nil {
			return err
		}
		out = dnsCryptInfo(st)
		return nil
	})
	return out, err
}

// SetDNSCryptUpstream sets the resolver the server asks ("ip" or "ip:port"; empty
// = the host's own).
func (m *Manager) SetDNSCryptUpstream(addr string) (*DNSCryptInfo, error) {
	addr = strings.TrimSpace(addr)
	if addr != "" {
		host, _, err := net.SplitHostPort(addr)
		if err != nil {
			host = addr
		}
		if net.ParseIP(host) == nil {
			return nil, invalid("the upstream must be an IP address, optionally with :port (got %q)", addr)
		}
	}
	var out *DNSCryptInfo
	err := m.Store.Update(func(st *store.State) error {
		st.Server.DNSCrypt.Upstream = addr
		out = dnsCryptInfo(st)
		return nil
	})
	return out, err
}
