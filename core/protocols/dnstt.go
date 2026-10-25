package protocols

import (
	"errors"

	"github.com/NoobforAl/omnitun/core/profile"
)

// DNSTT is the server's DNS tunnel identity: the zone delegated to it and the Noise key pair clients check it by.
type DNSTT struct {
	// Domain is the DNS zone delegated to the server, such as t.example.com. Empty until the operator sets it.
	Domain string
	// PublicKey and PrivateKey are 64 hex digits each.
	PublicKey, PrivateKey string
	// UpstreamPort is the loopback port of the SOCKS5 inbound the tunnel's streams are forwarded to. It is
	// what tells the users apart: every user has a login there, so per-user accounting and limits work as for
	// the other protocols.
	UpstreamPort int
}

// ErrNoDNSTTDomain is what Profile returns while no domain is set.
var ErrNoDNSTTDomain = errors.New("the DNS tunnel needs its domain first (omnitun-server dnstt domain <name>)")

// dnsttServer is the DNS tunnel: the server answers DNS queries for a zone delegated to it and carries the
// connections hidden in them, for users on networks where nothing but DNS gets out. The DNS side is a process
// started next to sing-box (a sidecar, see Spec.Sidecar); what it carries is handed to a loopback SOCKS5 inbound of
// sing-box, so users, accounting and quotas are the usual ones. It is slow and easy to notice by its volume of DNS
// queries, so it is off until asked for.
type dnsttServer struct{}

func (dnsttServer) Spec() Spec {
	return Spec{
		Key: "dnstt", Name: "DNS tunnel", Label: "DNS", Profile: profile.DNSTT,
		Description: "Carries connections inside DNS queries, for networks where nothing but DNS gets out. Slow, TCP only, and the volume of DNS queries is visible. Needs a domain delegated to this server (`dnstt domain`, then two DNS records) and UDP port 53 free.",
		Transport:   "udp", DefaultPort: 53, ShareLink: true, DefaultOff: true, Sidecar: true,
	}
}

func (dnsttServer) Inbounds(env Env, _ int, accts []Account) Config {
	in := obj{"type": "socks", "tag": "dnstt-upstream", "listen": "127.0.0.1", "listen_port": env.DNSTT.UpstreamPort}
	in["users"] = users(accts, func(a Account) obj { return obj{"username": a.Name, "password": a.Password} })
	return Config{Inbounds: []obj{in}}
}

func (d dnsttServer) Profile(env Env, port int, u Account) (*profile.Profile, error) {
	if env.DNSTT.Domain == "" {
		return nil, ErrNoDNSTTDomain
	}
	return &profile.Profile{
		Name: profileName(env, d.Spec()), Protocol: profile.DNSTT, Server: env.DNSTT.Domain, Port: port,
		Username: u.Name, Password: u.Password,
		DNSTT: &profile.DNSTTOpts{Domain: env.DNSTT.Domain, PubKey: env.DNSTT.PublicKey, Resolvers: dnsttDefaultResolvers()},
	}, nil
}

// dnsttDefaultResolvers are the resolvers a user's profile starts with: well-known public ones; the app can scan for
// the ones that work on the user's network.
func dnsttDefaultResolvers() []string {
	return []string{"udp://8.8.8.8:53", "udp://1.1.1.1:53", "https://dns.google/dns-query"}
}
