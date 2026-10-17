package manager

import (
	"net"
	"strings"

	"github.com/NoobforAl/omnitun/core/protocols"

	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/store"
)

// DNSCryptInfo describes the server's optional DNSCrypt resolver.
type DNSCryptInfo struct {
	Enabled      bool     `json:"enabled"`
	Port         int      `json:"port"`
	ProviderName string   `json:"provider_name"`
	PublicKey    string   `json:"public_key" doc:"Ed25519 key of the provider (hex), the one in the stamp"`
	Upstream     string   `json:"upstream,omitempty" doc:"Resolver the server asks; empty = 1.1.1.1, \"system\" = the host's own"`
	Listen       string   `json:"listen,omitempty" doc:"The one address it listens on (a VPN tunnel address or loopback); required before it can be enabled"`
	Allow        []string `json:"allow,omitempty" doc:"Extra source ranges allowed to query, besides loopback, the server itself and the VPN client ranges"`
	Stamp        string   `json:"stamp,omitempty" doc:"DNS stamp (sdns://...) to give to clients; empty while the resolver is off"`
}

func dnsCryptInfo(st *store.State) *DNSCryptInfo {
	p := st.Server.Protocols[store.DNSCryptKey]
	d := st.Server.DNSCrypt
	info := &DNSCryptInfo{ProviderName: d.ProviderName, PublicKey: d.PublicKey, Upstream: d.Upstream, Listen: d.Listen, Allow: d.Allow}
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

// SetDNSCryptUpstream sets the resolver the server asks: "ip" or "ip:port";
// empty = the public resolver 1.1.1.1; "system" = the host's own (resolv.conf),
// which may expose internal names, so it is only used when asked for.
func (m *Manager) SetDNSCryptUpstream(addr string) (*DNSCryptInfo, error) {
	addr = strings.TrimSpace(addr)
	if addr != "" && addr != protocols.UpstreamSystem {
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

// SetDNSCryptListen sets the one address the resolver listens on: a VPN tunnel
// address (10.30.0.1 for WireGuard users, 10.31.0.1 AmneziaWG) or loopback. A
// wildcard address is refused. A running server picks it up on its next reload.
func (m *Manager) SetDNSCryptListen(addr string) (*DNSCryptInfo, error) {
	a, err := store.ParseDNSCryptListen(addr)
	if err != nil {
		return nil, invalid("%v", err)
	}
	var out *DNSCryptInfo
	err = m.Store.Update(func(st *store.State) error {
		st.Server.DNSCrypt.Listen = a.String()
		out = dnsCryptInfo(st)
		return nil
	})
	return out, err
}

// SetDNSCryptAllow sets the extra source ranges allowed to query (none clears
// them). Loopback, the server's own addresses and the VPN client ranges are always allowed.
func (m *Manager) SetDNSCryptAllow(ranges []string) (*DNSCryptInfo, error) {
	prefixes, err := store.ParseDNSCryptAllow(ranges)
	if err != nil {
		return nil, invalid("%v", err)
	}
	list := make([]string, len(prefixes))
	for i, p := range prefixes {
		list[i] = p.String()
	}
	var out *DNSCryptInfo
	err = m.Store.Update(func(st *store.State) error {
		st.Server.DNSCrypt.Allow = list
		out = dnsCryptInfo(st)
		return nil
	})
	return out, err
}
