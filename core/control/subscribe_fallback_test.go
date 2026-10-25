package control

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/subscription"
)

const fallbackBody = "trojan://pw@a.example.com:443#A\ntrojan://pw@b.example.com:443#B"

// A subscription can name backup addresses: the first one that answers (and passes the signature check, when
// there is a key) is used, and when none does the error says so.
func TestSubscribeBackupAddresses(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	key := base64.StdEncoding.EncodeToString(pub)

	signed := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		subscription.Sign(priv, []byte(fallbackBody), w.Header(), r.URL.RequestURI(), time.Now())
		w.Write([]byte(fallbackBody))
	}))
	defer signed.Close()
	unsigned := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(fallbackBody))
	}))
	defer unsigned.Close()
	down := httptest.NewServer(http.NotFoundHandler())
	downURL := down.URL
	down.Close()

	s, addr := newTestServer(t, ServerConfig{})
	c, err := Dial(t.Context(), addr, s.Token())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	var res subscription.Result
	if err := c.Call(t.Context(), "subscribe", subscription.Request{URL: downURL, FallbackURLs: []string{signed.URL}}, &res); err != nil || len(res.Profiles) != 2 {
		t.Fatalf("a backup address should answer when the first is down: %v %+v", err, res)
	}

	// With a key, an unsigned answer is passed over for a signed one.
	res = subscription.Result{}
	if err := c.Call(t.Context(), "subscribe", subscription.Request{URL: unsigned.URL, FallbackURLs: []string{downURL, signed.URL}, PublicKey: key}, &res); err != nil {
		t.Fatal(err)
	}
	if len(res.Profiles) != 2 || !res.Info.Verified {
		t.Fatalf("the signed backup should be used and verified: %+v", res)
	}

	var ce *Error
	err = c.Call(t.Context(), "subscribe", subscription.Request{URL: unsigned.URL, FallbackURLs: []string{unsigned.URL}, PublicKey: key}, nil)
	if !errors.As(err, &ce) || ce.Code != CodeSubUnsigned || !strings.Contains(ce.Message, "1 backup address") {
		t.Fatalf("nothing is signed: %v", err)
	}

	err = c.Call(t.Context(), "subscribe", subscription.Request{URL: signed.URL, PublicKey: base64.StdEncoding.EncodeToString(make([]byte, 32))}, nil)
	if !errors.As(err, &ce) || ce.Code != CodeSubBadSignature {
		t.Fatalf("another provider's key: %v", err)
	}

	// A key that has seen a later answer refuses this one as a replay; the error says so.
	err = c.Call(t.Context(), "subscribe", subscription.Request{URL: signed.URL, PublicKey: key, NotBefore: time.Now().Add(time.Hour).Unix()}, nil)
	if !errors.As(err, &ce) || ce.Code != CodeSubStale {
		t.Fatalf("a replayed answer: %v", err)
	}

	err = c.Call(t.Context(), "subscribe", subscription.Request{URL: signed.URL, PublicKey: "nonsense"}, nil)
	if !errors.As(err, &ce) || ce.Code != CodeSubBadKey {
		t.Fatalf("a key that is not a key: %v", err)
	}

	err = c.Call(t.Context(), "subscribe", subscription.Request{URL: downURL, FallbackURLs: []string{downURL}}, nil)
	if !errors.As(err, &ce) || !strings.Contains(ce.Message, "backup address") {
		t.Fatalf("everything down: %v", err)
	}
}
