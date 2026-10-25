package subscription

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
)

// A signed subscription carries the header "X-Signature: ed25519=<base64>". The signature is made over the body,
// a zero byte, and the protocol-order headers in OrderText form, so neither the list nor the order the provider
// asks for can be changed without the provider's key. A client that has the key refuses anything else.
const (
	// SignatureHeader is the header the signature is in.
	SignatureHeader = "X-Signature"
	signaturePrefix = "ed25519="
	// OrderHeader names the protocol order: "Protocol-Order: vless-reality,hysteria2", and per country
	// "Protocol-Order-IR: hysteria2,vless-reality" (the country is an ISO 3166 code).
	OrderHeader = "Protocol-Order"
)

// ErrUnsigned is returned when a key is set but the answer carries no signature.
var ErrUnsigned = errors.New("the subscription is not signed")

// ErrBadSignature is returned when the signature does not belong to the answer and the key.
var ErrBadSignature = errors.New("the subscription's signature is wrong")

// ErrBadKey is returned for a signing key that is not a base64 Ed25519 public key.
var ErrBadKey = errors.New("the signing key is not a valid public key")

// ParseKey reads a signing key: 32 bytes as base64 (standard or URL, padded or not).
func ParseKey(s string) (ed25519.PublicKey, error) {
	s = strings.TrimSpace(s)
	for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
		if b, err := enc.DecodeString(s); err == nil && len(b) == ed25519.PublicKeySize {
			return ed25519.PublicKey(b), nil
		}
	}
	return nil, ErrBadKey
}

// OrderText is the protocol-order headers of h in one canonical text: a line "Name: a,b" for each, sorted by
// name, items lower-cased and trimmed. It is part of what is signed.
func OrderText(h http.Header) string {
	var lines []string
	for name, vals := range h {
		canon := http.CanonicalHeaderKey(name)
		if canon != OrderHeader && !strings.HasPrefix(canon, OrderHeader+"-") {
			continue
		}
		items := normalizeOrder(strings.Join(vals, ","))
		if len(items) > 0 {
			lines = append(lines, canon+": "+strings.Join(items, ","))
		}
	}
	sort.Strings(lines)
	if len(lines) == 0 {
		return ""
	}
	return strings.Join(lines, "\n") + "\n"
}

func normalizeOrder(s string) []string {
	var out []string
	for item := range strings.SplitSeq(s, ",") {
		if item = strings.ToLower(strings.TrimSpace(item)); item != "" {
			out = append(out, item)
		}
	}
	return out
}

func signedMessage(body []byte, h http.Header) []byte {
	msg := make([]byte, 0, len(body)+64)
	msg = append(msg, body...)
	msg = append(msg, 0)
	return append(msg, OrderText(h)...)
}

// Sign returns the value of the X-Signature header for body and the headers h that carry the protocol order.
func Sign(priv ed25519.PrivateKey, body []byte, h http.Header) string {
	return signaturePrefix + base64.StdEncoding.EncodeToString(ed25519.Sign(priv, signedMessage(body, h)))
}

// Verify checks the signature in h against body and key.
func Verify(pub ed25519.PublicKey, body []byte, h http.Header) error {
	v := strings.TrimSpace(h.Get(SignatureHeader))
	if v == "" {
		return ErrUnsigned
	}
	enc, ok := strings.CutPrefix(v, signaturePrefix)
	if !ok {
		return fmt.Errorf("%w: unknown signature type", ErrBadSignature)
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(enc))
	if err != nil || len(sig) != ed25519.SignatureSize {
		return ErrBadSignature
	}
	if !ed25519.Verify(pub, signedMessage(body, h), sig) {
		return ErrBadSignature
	}
	return nil
}

// protocolOrders reads the order headers: the default under "" and each country under its upper-case code.
func protocolOrders(h http.Header) map[string][]string {
	var out map[string][]string
	for name, vals := range h {
		canon := http.CanonicalHeaderKey(name)
		country, ok := "", canon == OrderHeader
		if !ok {
			if c, found := strings.CutPrefix(canon, OrderHeader+"-"); found && len(c) == 2 {
				country, ok = strings.ToUpper(c), true
			}
		}
		if !ok {
			continue
		}
		if items := normalizeOrder(strings.Join(vals, ",")); len(items) > 0 {
			if out == nil {
				out = map[string][]string{}
			}
			out[country] = items
		}
	}
	return out
}
