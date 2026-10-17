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
	// Upstream is the resolver the server asks, "ip:port"; empty means the
	// host's own (resolv.conf), and 1.1.1.1 if it names none.
	Upstream string
}

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
		Description: "A DNS resolver for this server's users, encrypted and authenticated with DNSCrypt (the resolver's key is in its DNS stamp: `link --stamp`). Not a way to connect. Answers anyone who can reach the port, so keep the port closed to the public unless that is wanted. TCP and UDP.",
		Transport:   "tcp+udp", DefaultPort: 5443, Host: true, DefaultOff: true, Service: true,
	}
}

// Profile: there is none, the resolver is not something to connect to.
func (dnscryptService) Profile(Env, int, Account) (*profile.Profile, error) {
	return nil, ErrNoProfile
}
