package store

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"slices"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// NewSigningKey makes the key that signs the subscription (base64 of an Ed25519 private key). Its public half
// goes to users in the subscription link, so a client that has it can tell an answer that was changed on the way.
func NewSigningKey() (string, error) {
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(priv), nil
}

// SigningPrivate is the subscription's signing key, or false while there is none (or it is damaged).
func (s Subscription) SigningPrivate() (ed25519.PrivateKey, bool) {
	b, err := base64.StdEncoding.DecodeString(s.SigningKey)
	if err != nil || len(b) != ed25519.PrivateKeySize {
		return nil, false
	}
	return ed25519.PrivateKey(b), true
}

// SigningPublic is the public half of the signing key as base64, the form clients take; empty while there is no key.
func (s Subscription) SigningPublic() string {
	priv, ok := s.SigningPrivate()
	if !ok {
		return ""
	}
	return base64.StdEncoding.EncodeToString(priv.Public().(ed25519.PublicKey))
}

// ensureSubscriptionKey gives a state with no signing key (one made before subscriptions were signed) a new one,
// and reports whether it changed.
func (st *State) ensureSubscriptionKey() (bool, error) {
	if _, ok := st.Server.Subscription.SigningPrivate(); ok {
		return false, nil
	}
	k, err := NewSigningKey()
	if err != nil {
		return false, err
	}
	st.Server.Subscription.SigningKey = k
	return true, nil
}

// RotateSigningKey replaces the signing key. Users must take the new public key (it is in the new subscription
// link); until they do, clients that hold the old one refuse the subscription.
func (st *State) RotateSigningKey() error {
	k, err := NewSigningKey()
	if err != nil {
		return err
	}
	st.Server.Subscription.SigningKey = k
	return nil
}

// ParseProtocolOrder checks a protocol order: a comma-separated list of client protocol names (vless, hysteria2,
// trojan, ...), each at most once. An empty list is allowed and clears the order.
func ParseProtocolOrder(list string) ([]string, error) {
	var out []string
	known := knownClientProtocols()
	for item := range strings.SplitSeq(list, ",") {
		item = strings.ToLower(strings.TrimSpace(item))
		if item == "" {
			continue
		}
		if !slices.Contains(known, item) {
			return nil, fmt.Errorf("%q is not a protocol (use names such as vless, hysteria2, trojan, shadowsocks, wireguard)", item)
		}
		if slices.Contains(out, item) {
			return nil, fmt.Errorf("%q is listed twice", item)
		}
		out = append(out, item)
	}
	return out, nil
}

func knownClientProtocols() []string {
	var out []string
	for _, f := range profile.Forms() {
		out = append(out, f.Protocol)
	}
	return out
}
