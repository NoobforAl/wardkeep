package protocols

import (
	"errors"

	"github.com/NoobforAl/omnitun/core/profile"
)

// DNSCrypt is the server's DNSCrypt resolver identity: the provider name and
// the long-term Ed25519 key the resolver's certificates are signed with. Its
// public half is in the resolver's DNS stamp, so changing the key changes the
// stamp. The short-term keys are made by the running server and rotated there.
type DNSCrypt struct {
	// ProviderName is "2.dnscrypt-cert.<name>".
	ProviderName string
	// PublicKey and PrivateKey are hex: 32 and 64 bytes.
	PublicKey, PrivateKey string
	// Upstream is the resolver the server asks, "ip:port"; empty means the public
	// resolver 1.1.1.1, and UpstreamSystem the host's own (resolv.conf).
	Upstream string
	// Listen is the one address the resolver listens on (a VPN tunnel address or
	// loopback). There is no default: an unset or wildcard address is refused, so
	// the resolver is never open on the public interface by accident.
	Listen string
	// Allow lists extra source ranges (CIDRs) that may query, on top of loopback,
	// the server's own addresses and the VPN client ranges.
	Allow []string
}

// UpstreamSystem as DNSCrypt.Upstream makes the resolver ask the host's own resolver.
const UpstreamSystem = "system"

// ErrNoProfile is what Profile returns for a service that is not a way to connect.
var ErrNoProfile = errors.New("this is a service for the VPN's users, not a way to connect")

// dnscryptService is the optional DNSCrypt resolver of the server. It is not a
// VPN protocol: it answers DNS for whoever is connected (through any of the
// protocols) so the VPN's DNS is private and under the operator's control. It
// is served by a process-level server (server/hostproto) and is off by default.
type dnscryptService struct{ hostBase }

func (dnscryptService) Spec() Spec {
	return Spec{
		Key: "dnscrypt", Name: "DNSCrypt resolver", Label: "DNSCrypt", Profile: "",
		Description: "A DNS resolver for this server's users, encrypted and authenticated with DNSCrypt (the resolver's key is in its DNS stamp: `link --stamp`). Not a way to connect. Needs the address to listen on first (`dnscrypt listen <ip>`, a VPN tunnel address such as 10.30.0.1); answers only the VPN's clients, the server itself and ranges you allow, and asks a public resolver unless you choose another. TCP and UDP.",
		Transport:   "tcp+udp", DefaultPort: 5443, Host: true, DefaultOff: true, Service: true,
	}
}

// Profile: there is none, the resolver is not something to connect to.
func (dnscryptService) Profile(Env, int, Account) (*profile.Profile, error) {
	return nil, ErrNoProfile
}
