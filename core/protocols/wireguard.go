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
	for _, acct := range accts {
		allowed := []string{acct.WGAddress}
		if env.IPv6 {
			if a6, err := WGAddress6(acct.WGAddress); err == nil {
				allowed = append(allowed, a6)
			}
		}
		peers = append(peers, obj{"public_key": acct.WGPublicKey, "allowed_ips": allowed})
	}
	return Config{Endpoints: []obj{{
		"type": "wireguard", "tag": "wireguard", "system": false, "name": "wg-server", "mtu": wireguardMTU,
		"address": addresses, "private_key": env.WireGuard.PrivateKey,
		"listen_port": port, "peers": peers,
	}}}
}

func (w wireguard) Profile(env Env, port int, acct Account) (*profile.Profile, error) {
	if acct.WGPrivateKey == "" || acct.WGAddress == "" {
		return nil, fmt.Errorf("user %s has no WireGuard key or address", acct.Name)
	}
	address := []string{acct.WGAddress}
	if env.IPv6 {
		a6, err := WGAddress6(acct.WGAddress)
		if err != nil {
			return nil, err
		}
		address = append(address, a6)
	}
	return &profile.Profile{
		Name: profileName(env, w.Spec()), Protocol: profile.WireGuard, Server: env.Host, Port: port,
		WireGuard: &profile.WG{
			PrivateKey: acct.WGPrivateKey, PeerPublicKey: env.WireGuard.PublicKey,
			Address: address, AllowedIPs: []string{"0.0.0.0/0", "::/0"},
			DNS: []string{"1.1.1.1", "8.8.8.8"}, MTU: wireguardMTU, Keepalive: 25,
		},
	}, nil
}

// File is the user's wg-quick style configuration, importable by the official
// WireGuard apps.
func (w wireguard) File(env Env, port int, acct Account) (string, string, error) {
	prof, err := w.Profile(env, port, acct)
	if err != nil {
		return "", "", err
	}
	wgOpts := prof.WireGuard
	var sb strings.Builder
	fmt.Fprintf(&sb, "# %s (WireGuard) for %s\n[Interface]\nPrivateKey = %s\nAddress = %s\nDNS = %s\nMTU = %d\n\n",
		env.Name, acct.Name, wgOpts.PrivateKey, strings.Join(wgOpts.Address, ", "), strings.Join(wgOpts.DNS, ", "), wgOpts.MTU)
	fmt.Fprintf(&sb, "[Peer]\nPublicKey = %s\nAllowedIPs = %s\nEndpoint = %s:%d\nPersistentKeepalive = %d\n",
		wgOpts.PeerPublicKey, strings.Join(wgOpts.AllowedIPs, ", "), endpointHost(env.Host), port, wgOpts.Keepalive)
	return env.Name + "-wireguard.conf", sb.String(), nil
}

// endpointHost brackets an IPv6 literal.
func endpointHost(h string) string {
	if strings.Contains(h, ":") && !strings.HasPrefix(h, "[") {
		return "[" + h + "]"
	}
	return h
}
