package subscription

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// signedServer answers with the test links, signed by priv (none: unsigned) for the path signPath (empty: the one
// asked for). tamper runs after signing and may change the headers and the body.
func signedServer(t *testing.T, priv ed25519.PrivateKey, headers map[string]string, signPath string, tamper func(h http.Header, body []byte) []byte) *httptest.Server {
	t.Helper()
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := []byte(base64.StdEncoding.EncodeToString([]byte(links)))
		for k, v := range headers {
			w.Header().Set(k, v)
		}
		if priv != nil {
			path := signPath
			if path == "" {
				path = r.URL.Path
			}
			Sign(priv, body, w.Header(), path, time.Now())
		}
		if tamper != nil {
			body = tamper(w.Header(), body)
		}
		w.Write(body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func keyPair(t *testing.T) (ed25519.PrivateKey, string) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return priv, base64.StdEncoding.EncodeToString(pub)
}

func fetchWith(t *testing.T, srv *httptest.Server, key string, notBefore int64) (*Result, error) {
	t.Helper()
	pool := srv.Client().Transport.(*http.Transport).TLSClientConfig.RootCAs
	return Fetch(t.Context(), Request{URL: srv.URL + "/sub/abc", PublicKey: key, NotBefore: notBefore}, pool)
}

var meta = map[string]string{
	"Subscription-Userinfo":   "upload=1; download=2; total=1000; expire=1893456000",
	"Profile-Update-Interval": "12",
	"Profile-Title":           "My Provider",
}

func TestSignedSubscription(t *testing.T) {
	priv, pub := keyPair(t)
	_, otherPub := keyPair(t)

	t.Run("valid", func(t *testing.T) {
		before := time.Now().Unix()
		res, err := fetchWith(t, signedServer(t, priv, meta, "", nil), pub, 0)
		if err != nil {
			t.Fatal(err)
		}
		if !res.Info.Verified || len(res.Profiles) != 2 || res.Info.SignedAt < before || res.Info.Total != 1000 {
			t.Fatalf("verified = %v, profiles = %d, signed at %d, info = %+v", res.Info.Verified, len(res.Profiles), res.Info.SignedAt, res.Info)
		}
	})
	t.Run("no key set: the signature is not looked at", func(t *testing.T) {
		res, err := fetchWith(t, signedServer(t, priv, nil, "", nil), "", 0)
		if err != nil {
			t.Fatal(err)
		}
		if res.Info.Verified || res.Info.SignedAt != 0 {
			t.Error("nothing was verified")
		}
	})
	t.Run("unsigned", func(t *testing.T) {
		if _, err := fetchWith(t, signedServer(t, nil, nil, "", nil), pub, 0); !errors.Is(err, ErrUnsigned) {
			t.Fatalf("error = %v, want ErrUnsigned", err)
		}
	})
	t.Run("wrong key", func(t *testing.T) {
		if _, err := fetchWith(t, signedServer(t, priv, nil, "", nil), otherPub, 0); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("changed body", func(t *testing.T) {
		srv := signedServer(t, priv, nil, "", func(_ http.Header, body []byte) []byte {
			return []byte(base64.StdEncoding.EncodeToString([]byte("trojan://pw@evil.example.com:443#E")))
		})
		if _, err := fetchWith(t, srv, pub, 0); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("changed order", func(t *testing.T) {
		srv := signedServer(t, priv, map[string]string{OrderHeader: "vless-reality,trojan"}, "", func(h http.Header, body []byte) []byte {
			h.Set(OrderHeader, "trojan,vless-reality")
			return body
		})
		if _, err := fetchWith(t, srv, pub, 0); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	// The usage bar, the expiry, the title and the refresh interval are signed too.
	for _, header := range []string{"Subscription-Userinfo", "Profile-Update-Interval", "Profile-Title"} {
		t.Run("changed "+header, func(t *testing.T) {
			srv := signedServer(t, priv, meta, "", func(h http.Header, body []byte) []byte {
				h.Set(header, "9999")
				return body
			})
			if _, err := fetchWith(t, srv, pub, 0); !errors.Is(err, ErrBadSignature) {
				t.Fatalf("error = %v, want ErrBadSignature", err)
			}
		})
	}
	t.Run("answer for another address", func(t *testing.T) {
		srv := signedServer(t, priv, nil, "/sub/someone-else", nil)
		if _, err := fetchWith(t, srv, pub, 0); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("an answer signed for another path must not verify: %v", err)
		}
	})
	t.Run("no signing time", func(t *testing.T) {
		srv := signedServer(t, priv, nil, "", func(h http.Header, body []byte) []byte {
			h.Del(SignatureTimeHeader)
			return body
		})
		if _, err := fetchWith(t, srv, pub, 0); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("changed signing time", func(t *testing.T) {
		srv := signedServer(t, priv, nil, "", func(h http.Header, body []byte) []byte {
			h.Set(SignatureTimeHeader, "1")
			return body
		})
		if _, err := fetchWith(t, srv, pub, 0); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("bad key", func(t *testing.T) {
		if _, err := fetchWith(t, signedServer(t, priv, nil, "", nil), "not a key", 0); !errors.Is(err, ErrBadKey) {
			t.Fatalf("error = %v, want ErrBadKey", err)
		}
	})
}

// A client refuses an answer signed before the last one it accepted: a list somebody kept and plays back.
func TestReplayedAnswerIsRefused(t *testing.T) {
	priv, pub := keyPair(t)
	srv := signedServer(t, priv, nil, "", nil)

	first, err := fetchWith(t, srv, pub, 0)
	if err != nil {
		t.Fatal(err)
	}
	// The same moment (or later) is fine.
	if _, err := fetchWith(t, srv, pub, first.Info.SignedAt); err != nil {
		t.Fatalf("an answer signed at the same time should be accepted: %v", err)
	}
	// An answer signed before the last accepted one is a replay, however valid its signature.
	if _, err := fetchWith(t, srv, pub, time.Now().Add(time.Hour).Unix()); !errors.Is(err, ErrStale) {
		t.Fatalf("error = %v, want ErrStale", err)
	}
}

func TestProtocolOrderOnlyFromVerifiedAnswers(t *testing.T) {
	priv, pub := keyPair(t)
	order := map[string]string{OrderHeader: "Vless-Reality, hysteria2", OrderHeader + "-IR": "trojan"}

	res, err := fetchWith(t, signedServer(t, priv, order, "", nil), pub, 0)
	if err != nil {
		t.Fatal(err)
	}
	got := res.Info.ProtocolOrder
	if len(got) != 2 || len(got[""]) != 2 || got[""][0] != "vless-reality" || got[""][1] != "hysteria2" || len(got["IR"]) != 1 || got["IR"][0] != "trojan" {
		t.Fatalf("order = %v", got)
	}

	// The same headers on an answer nobody checked are ignored.
	res, err = fetchWith(t, signedServer(t, nil, order, "", nil), "", 0)
	if err != nil {
		t.Fatal(err)
	}
	if res.Info.ProtocolOrder != nil {
		t.Fatalf("an unverified answer must not reorder anything, got %v", res.Info.ProtocolOrder)
	}
}

func TestOrderTextIsCanonical(t *testing.T) {
	a, b := http.Header{}, http.Header{}
	a.Set("Protocol-Order", "Vless, trojan")
	a.Set("Protocol-Order-IR", "ss")
	b.Set("protocol-order-ir", " SS ")
	b.Set("PROTOCOL-ORDER", "vless,TROJAN")
	if OrderText(a) != OrderText(b) {
		t.Errorf("%q != %q", OrderText(a), OrderText(b))
	}
	if OrderText(http.Header{"Content-Type": {"x"}}) != "" {
		t.Error("other headers are not part of the order text")
	}
}
