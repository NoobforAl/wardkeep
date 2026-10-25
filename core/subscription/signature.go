package subscription

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"
)

// A signed subscription carries "X-Signature: ed25519=<base64>" and "X-Signature-Time: <unix seconds>". The
// signature is made over one message (see signedMessage) that binds the answer to:
//
//   - the request target it was asked for (path and query, as the client sent them), so one user's answer cannot be
//     served as another's, and a token in the query counts;
//   - the time it was signed, so a client can refuse an answer older than the last it accepted (a replayed old list);
//   - the metadata headers the client shows and acts on (usage, expiry, title, refresh interval, protocol order);
//   - the body.
//
// A client that has the key refuses anything that does not verify, and does not follow redirects (an answer is
// verified against the address the client asked, not one it was sent to). The time is only compared with the last
// answer the client accepted, never with its own clock, so a phone with a wrong clock still works.
//
// What the signature cannot bind is a credential the client sends in a header (basic or bearer auth): two users of
// one address would get answers that differ only by that credential. A provider that signs should give each user
// their own address (the Wardkeep server puts a token in the path).
const (
	// SignatureHeader is the header the signature is in.
	SignatureHeader = "X-Signature"
	// SignatureTimeHeader is when the answer was signed (Unix seconds).
	SignatureTimeHeader = "X-Signature-Time"
	signaturePrefix     = "ed25519="
	messageTag          = "wardkeep-subscription-v1"
	// OrderHeader names the protocol order: "Protocol-Order: vless,hysteria2", and per country
	// "Protocol-Order-IR: hysteria2,vless" (the country is an ISO 3166 code).
	OrderHeader = "Protocol-Order"
)

// signedMeta are the metadata headers (besides the protocol order) that parseInfo reads and the signature covers.
var signedMeta = []string{"Profile-Title", "Profile-Update-Interval", "Subscription-Userinfo"}

// ErrUnsigned is returned when a key is set but the answer carries no signature.
var ErrUnsigned = errors.New("the subscription is not signed")

// ErrBadSignature is returned when the signature does not belong to the answer and the key.
var ErrBadSignature = errors.New("the subscription's signature is wrong")

// ErrStale is returned for a correctly signed answer that is older than one already accepted: a replayed list.
var ErrStale = errors.New("the subscription is older than the last one accepted")

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

func isOrderHeader(canon string) bool {
	return canon == OrderHeader || strings.HasPrefix(canon, OrderHeader+"-")
}

// OrderText is the protocol-order headers of h in one canonical text: a line "Name: a,b" for each, sorted by
// name, items lower-cased and trimmed.
func OrderText(h http.Header) string {
	var lines []string
	for name, vals := range h {
		canon := http.CanonicalHeaderKey(name)
		if !isOrderHeader(canon) {
			continue
		}
		if items := normalizeOrder(strings.Join(vals, ",")); len(items) > 0 {
			lines = append(lines, canon+": "+strings.Join(items, ","))
		}
	}
	return canonicalLines(lines)
}

// metaText is the signed metadata headers (not the order) as "Name: value" lines, sorted.
func metaText(h http.Header) string {
	var lines []string
	for _, name := range signedMeta {
		if v := strings.TrimSpace(h.Get(name)); v != "" {
			lines = append(lines, name+": "+v)
		}
	}
	return canonicalLines(lines)
}

func canonicalLines(lines []string) string {
	if len(lines) == 0 {
		return ""
	}
	sort.Strings(lines)
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

// signedMessage is what the signature is made over: a version tag, the request target, the time, the metadata and
// order headers, a zero byte, and the body.
func signedMessage(body []byte, h http.Header, target string, signedAt int64) []byte {
	head := messageTag + "\n" + target + "\n" + strconv.FormatInt(signedAt, 10) + "\n" + metaText(h) + OrderText(h)
	msg := make([]byte, 0, len(head)+1+len(body))
	msg = append(msg, head...)
	msg = append(msg, 0)
	return append(msg, body...)
}

// Sign signs an answer for the request target (the URL's RequestURI: path and query) and sets X-Signature and X-Signature-Time on h, which must already
// carry the metadata and protocol-order headers (they are part of what is signed).
func Sign(priv ed25519.PrivateKey, body []byte, h http.Header, target string, now time.Time) {
	at := now.Unix()
	h.Set(SignatureTimeHeader, strconv.FormatInt(at, 10))
	h.Set(SignatureHeader, signaturePrefix+base64.StdEncoding.EncodeToString(ed25519.Sign(priv, signedMessage(body, h, target, at))))
}

// Verify checks the signature in h against body, the request target that was asked for and the key. It returns when the
// answer was signed.
func Verify(pub ed25519.PublicKey, body []byte, h http.Header, target string) (signedAt int64, err error) {
	v := strings.TrimSpace(h.Get(SignatureHeader))
	if v == "" {
		return 0, ErrUnsigned
	}
	enc, ok := strings.CutPrefix(v, signaturePrefix)
	if !ok {
		return 0, fmt.Errorf("%w: unknown signature type", ErrBadSignature)
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(enc))
	if err != nil || len(sig) != ed25519.SignatureSize {
		return 0, ErrBadSignature
	}
	signedAt, err = strconv.ParseInt(strings.TrimSpace(h.Get(SignatureTimeHeader)), 10, 64)
	if err != nil || signedAt <= 0 {
		return 0, fmt.Errorf("%w: no signing time", ErrBadSignature)
	}
	if !ed25519.Verify(pub, signedMessage(body, h, target, signedAt), sig) {
		return 0, ErrBadSignature
	}
	return signedAt, nil
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
