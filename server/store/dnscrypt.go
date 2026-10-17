package store

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"regexp"
	"strings"
)

// DNSCrypt is the identity of the server's optional DNSCrypt resolver: a
// long-term Ed25519 key that signs the resolver's certificates, and the
// provider name. The public key and the provider name are in the resolver's
// DNS stamp (`omnitun-server link --stamp`), so changing the key changes the
// stamp and every client has to take the new one. The short-term keys the
// certificates carry are made by the running server and replaced regularly;
// they are not kept here.
type DNSCrypt struct {
	// ProviderName is "2.dnscrypt-cert.<name>".
	ProviderName string `json:"provider_name"`
	// PublicKey (32 bytes) and PrivateKey (64 bytes) are hex.
	PublicKey  string `json:"public_key"`
	PrivateKey string `json:"private_key"`
	// Upstream is the "ip:port" of the resolver the server asks. Empty: the
	// host's own resolver (resolv.conf), or 1.1.1.1 if it names none.
	Upstream string `json:"upstream,omitempty"`
}

// DNSCryptKey is the protocol key of the resolver.
const DNSCryptKey = "dnscrypt"

const dnsCryptPrefix = "2.dnscrypt-cert."

var nonName = regexp.MustCompile(`[^a-z0-9-]+`)

// DNSCryptProviderName makes the provider name for a server called name.
func DNSCryptProviderName(name string) string {
	n := strings.Trim(nonName.ReplaceAllString(strings.ToLower(name), "-"), "-")
	if n == "" {
		n = "omnitun"
	}
	if len(n) > 40 {
		n = strings.Trim(n[:40], "-")
	}
	return dnsCryptPrefix + n
}

// NewDNSCrypt makes a new identity (a key pair and the provider name) for a server called name.
func NewDNSCrypt(name string) (DNSCrypt, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return DNSCrypt{}, err
	}
	return DNSCrypt{
		ProviderName: DNSCryptProviderName(name),
		PublicKey:    hex.EncodeToString(pub),
		PrivateKey:   hex.EncodeToString(priv),
	}, nil
}

// Valid reports whether the stored identity is complete and the keys fit together.
func (d DNSCrypt) Valid() error {
	priv, err := hex.DecodeString(d.PrivateKey)
	if err != nil || len(priv) != ed25519.PrivateKeySize {
		return fmt.Errorf("the DNSCrypt private key is not 64 bytes of hex")
	}
	pub, err := hex.DecodeString(d.PublicKey)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		return fmt.Errorf("the DNSCrypt public key is not 32 bytes of hex")
	}
	if !ed25519.PublicKey(pub).Equal(ed25519.PrivateKey(priv).Public()) {
		return fmt.Errorf("the DNSCrypt public key does not belong to the private key")
	}
	if !strings.HasPrefix(d.ProviderName, dnsCryptPrefix) || len(d.ProviderName) == len(dnsCryptPrefix) {
		return fmt.Errorf("the DNSCrypt provider name must start with %s", dnsCryptPrefix)
	}
	return nil
}

// ensureDNSCrypt gives a state that has no DNSCrypt identity (one made before
// the resolver existed) a new one, and reports whether it changed.
func (st *State) ensureDNSCrypt() (bool, error) {
	if st.Server.DNSCrypt.Valid() == nil {
		return false, nil
	}
	d, err := NewDNSCrypt(st.Server.Name)
	if err != nil {
		return false, err
	}
	d.Upstream = st.Server.DNSCrypt.Upstream
	st.Server.DNSCrypt = d
	return true, nil
}

// RotateDNSCryptKey makes a new long-term key, which changes the resolver's
// stamp; users of the resolver must take the new stamp. The provider name and
// upstream stay.
func (st *State) RotateDNSCryptKey() error {
	d, err := NewDNSCrypt(st.Server.Name)
	if err != nil {
		return err
	}
	if st.Server.DNSCrypt.ProviderName != "" {
		d.ProviderName = st.Server.DNSCrypt.ProviderName
	}
	d.Upstream = st.Server.DNSCrypt.Upstream
	st.Server.DNSCrypt = d
	return nil
}
