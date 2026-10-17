package protocols

import (
	"fmt"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// wireguardMTU is conservative: it fits inside most mobile and PPPoE links.
const wireguardMTU = 1380

// WireGuard is the server's WireGuard identity and tunnel network.
type WireGuard struct {
	PrivateKey, PublicKey string
	// Address is the server's address in the tunnel ("10.30.0.1/16").
	Address string
}

type wireguard struct{}

func (wireguard) Spec() Spec {
	return Spec{
		Key: "wireguard", Name: "WireGuard", Label: "WireGuard", Profile: profile.WireGuard,
		Description: "The standard fast VPN: every user gets a key pair and an address; also works in the official WireGuard apps (.conf download). UDP only.",
		Transport:   "udp", DefaultPort: 51820, ShareLink: true, FileExt: ".conf",
	}
}

func (wireguard) Inbounds(env Env, port int, accts []Account) Config {
	peers := make([]any, 0, len(accts))
	addresses := []string{env.WireGuard.Address}
	if env.IPv6 {
		addresses = append(addresses, wgServerAddress6)
	}
	for _, a := range accts {
		allowed := []string{a.WGAddress}
		if env.IPv6 {
			if a6, err := WGAddress6(a.WGAddress); err == nil {
				allowed = append(allowed, a6)
			}
		}
		peers = append(peers, obj{"public_key": a.WGPublicKey, "allowed_ips": allowed})
	}
	return Config{Endpoints: []obj{{
		"type": "wireguard", "tag": "wireguard", "system": false, "name": "wg-server", "mtu": wireguardMTU,
		"address": addresses, "private_key": env.WireGuard.PrivateKey,
		"listen_port": port, "peers": peers,
	}}}
}

func (w wireguard) Profile(env Env, port int, u Account) (*profile.Profile, error) {
	if u.WGPrivateKey == "" || u.WGAddress == "" {
		return nil, fmt.Errorf("user %s has no WireGuard key or address", u.Name)
	}
	address := []string{u.WGAddress}
	if env.IPv6 {
		a6, err := WGAddress6(u.WGAddress)
		if err != nil {
			return nil, err
		}
		address = append(address, a6)
	}
	return &profile.Profile{
		Name: profileName(env, w.Spec()), Protocol: profile.WireGuard, Server: env.Host, Port: port,
		WireGuard: &profile.WG{
			PrivateKey: u.WGPrivateKey, PeerPublicKey: env.WireGuard.PublicKey,
			Address: address, AllowedIPs: []string{"0.0.0.0/0", "::/0"},
			DNS: []string{"1.1.1.1", "8.8.8.8"}, MTU: wireguardMTU, Keepalive: 25,
		},
	}, nil
}

// File is the user's wg-quick style configuration, importable by the official
// WireGuard apps.
func (w wireguard) File(env Env, port int, u Account) (string, string, error) {
	p, err := w.Profile(env, port, u)
	if err != nil {
		return "", "", err
	}
	g := p.WireGuard
	var b strings.Builder
	fmt.Fprintf(&b, "# %s (WireGuard) for %s\n[Interface]\nPrivateKey = %s\nAddress = %s\nDNS = %s\nMTU = %d\n\n",
		env.Name, u.Name, g.PrivateKey, strings.Join(g.Address, ", "), strings.Join(g.DNS, ", "), g.MTU)
	fmt.Fprintf(&b, "[Peer]\nPublicKey = %s\nAllowedIPs = %s\nEndpoint = %s:%d\nPersistentKeepalive = %d\n",
		g.PeerPublicKey, strings.Join(g.AllowedIPs, ", "), endpointHost(env.Host), port, g.Keepalive)
	return env.Name + "-wireguard.conf", b.String(), nil
}

// endpointHost brackets an IPv6 literal.
func endpointHost(h string) string {
	if strings.Contains(h, ":") && !strings.HasPrefix(h, "[") {
		return "[" + h + "]"
	}
	return h
}
