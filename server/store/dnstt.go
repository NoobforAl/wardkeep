package store

import (
	"encoding/hex"
	"fmt"
	"strings"

	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
)

// DNSTTKey is the protocol key of the DNS tunnel.
const DNSTTKey = "dnstt"

// DefaultDNSTTUpstreamPort is the loopback port of the SOCKS5 inbound the tunnel's streams go to.
const DefaultDNSTTUpstreamPort = 5300

// DNSTT is the identity of the server's optional DNS tunnel: the zone delegated to it and the Noise key pair clients
// check it by. The public key is in every user's link, so changing the key means every user needs a new link.
type DNSTT struct {
	// Domain is the DNS zone delegated to the server, such as t.example.com; empty until the operator sets it.
	Domain string `json:"domain,omitempty"`
	// PublicKey and PrivateKey are 64 hex digits each.
	PublicKey  string `json:"public_key"`
	PrivateKey string `json:"private_key"`
	// UpstreamPort is the loopback port of the SOCKS5 inbound the tunnel's streams are forwarded to.
	UpstreamPort int `json:"upstream_port"`
}

// NewDNSTT makes a new identity: a key pair and the default upstream port.
func NewDNSTT() (DNSTT, error) {
	priv, err := noise.GeneratePrivkey()
	if err != nil {
		return DNSTT{}, err
	}
	return DNSTT{
		PublicKey: noise.EncodeKey(noise.PubkeyFromPrivkey(priv)), PrivateKey: noise.EncodeKey(priv),
		UpstreamPort: DefaultDNSTTUpstreamPort,
	}, nil
}

// Valid reports whether the stored keys are complete and fit together.
func (d DNSTT) Valid() error {
	priv, err := hex.DecodeString(d.PrivateKey)
	if err != nil || len(priv) != noise.KeyLen {
		return fmt.Errorf("the DNS tunnel's private key is not %d hex digits", noise.KeyLen*2)
	}
	if d.PublicKey != noise.EncodeKey(noise.PubkeyFromPrivkey(priv)) {
		return fmt.Errorf("the DNS tunnel's public key does not belong to its private key")
	}
	if d.UpstreamPort < 1 || d.UpstreamPort > 65535 {
		return fmt.Errorf("the DNS tunnel's upstream port %d is out of range", d.UpstreamPort)
	}
	return nil
}

// CheckDNSTTDomain checks the zone name an operator gives: a host name of at least two labels, letters, digits
// and hyphens; trailing dot and case are dropped. It returns the name as it is stored.
func CheckDNSTTDomain(s string) (string, error) {
	s = strings.ToLower(strings.TrimSuffix(strings.TrimSpace(s), "."))
	labels := strings.Split(s, ".")
	if len(labels) < 2 || len(s) > 200 {
		return "", fmt.Errorf("%q is not a domain with a parent zone (use something like t.example.com)", s)
	}
	for _, l := range labels {
		if l == "" || len(l) > 63 || l[0] == '-' || l[len(l)-1] == '-' {
			return "", fmt.Errorf("%q is not a valid domain name", s)
		}
		for _, r := range l {
			if !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '-') {
				return "", fmt.Errorf("%q is not a valid domain name (letters, digits and hyphens only)", s)
			}
		}
	}
	return s, nil
}

// ensureDNSTT gives a state with no DNS tunnel identity (one made before the tunnel existed) a new one, and reports
// whether it changed. It never touches the domain.
func (st *State) ensureDNSTT() (bool, error) {
	if st.Server.DNSTT.Valid() == nil {
		return false, nil
	}
	d, err := NewDNSTT()
	if err != nil {
		return false, err
	}
	d.Domain = st.Server.DNSTT.Domain
	if p := st.Server.DNSTT.UpstreamPort; p >= 1 && p <= 65535 {
		d.UpstreamPort = p
	}
	st.Server.DNSTT = d
	return true, nil
}

// RotateDNSTTKey makes a new key pair; every user needs the new link.
func (st *State) RotateDNSTTKey() error {
	d, err := NewDNSTT()
	if err != nil {
		return err
	}
	d.Domain, d.UpstreamPort = st.Server.DNSTT.Domain, max(st.Server.DNSTT.UpstreamPort, 1)
	st.Server.DNSTT = d
	return nil
}
