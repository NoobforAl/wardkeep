package serverconf

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"strconv"

	"github.com/NoobforAl/omnitun/core/dnscrypt"
	"github.com/NoobforAl/omnitun/core/protocols"
	"github.com/NoobforAl/omnitun/server/store"
)

func dnsCryptEnv(srv store.Server) protocols.DNSCrypt {
	d := srv.DNSCrypt
	return protocols.DNSCrypt{ProviderName: d.ProviderName, PublicKey: d.PublicKey, PrivateKey: d.PrivateKey, Upstream: d.Upstream, Listen: d.Listen, Allow: d.Allow}
}

// ErrDNSCryptOff is returned when the resolver is not enabled.
var ErrDNSCryptOff = errors.New("the DNSCrypt resolver is off (enable it with: proto enable dnscrypt)")

// DNSCryptStamp is the DNS stamp ("sdns://...") of the server's DNSCrypt
// resolver: the address it listens on, the port, the provider name and public key.
// Clients (Wardkeep's DNS screen, dnscrypt-proxy, ...) are given this string.
// The resolver keeps no logs and blocks nothing on purpose; it validates DNSSEC
// only as far as its upstream does, so that property is not claimed.
func DNSCryptStamp(st *store.State) (string, error) {
	p := st.Server.Protocols[store.DNSCryptKey]
	if p == nil || !p.Enabled {
		return "", ErrDNSCryptOff
	}
	d := st.Server.DNSCrypt
	if err := d.Valid(); err != nil {
		return "", err
	}
	pub, _ := hex.DecodeString(d.PublicKey)
	// The stamp names the address the resolver listens on (a VPN tunnel address),
	// which is where the VPN's users reach it from inside the tunnel.
	listen, err := store.ParseDNSCryptListen(d.Listen)
	if err != nil {
		return "", store.ErrDNSCryptListen
	}
	addr := net.JoinHostPort(listen.String(), strconv.Itoa(p.Port))
	stamp := dnscrypt.Stamp{
		Kind: dnscrypt.KindDNSCrypt, Props: dnscrypt.PropNoLog | dnscrypt.PropNoFilter,
		Addr: addr, PublicKey: pub, ProviderName: d.ProviderName,
	}
	s := stamp.String()
	if _, err := dnscrypt.ParseDNSCryptStamp(s); err != nil {
		return "", fmt.Errorf("the stamp could not be made: %w", err)
	}
	return s, nil
}
