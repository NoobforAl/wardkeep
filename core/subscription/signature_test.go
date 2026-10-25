package subscription

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

// signedServer answers with the test links, signed by priv unless tamper says otherwise.
func signedServer(t *testing.T, priv ed25519.PrivateKey, order map[string]string, tamper func(h http.Header, body []byte) []byte) *httptest.Server {
	t.Helper()
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := []byte(base64.StdEncoding.EncodeToString([]byte(links)))
		for k, v := range order {
			w.Header().Set(k, v)
		}
		if priv != nil {
			w.Header().Set(SignatureHeader, Sign(priv, body, w.Header()))
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

func fetchWith(t *testing.T, srv *httptest.Server, key string) (*Result, error) {
	t.Helper()
	pool := srv.Client().Transport.(*http.Transport).TLSClientConfig.RootCAs
	return Fetch(t.Context(), Request{URL: srv.URL + "/sub", PublicKey: key}, pool)
}

func TestSignedSubscription(t *testing.T) {
	priv, pub := keyPair(t)
	_, otherPub := keyPair(t)

	t.Run("valid", func(t *testing.T) {
		res, err := fetchWith(t, signedServer(t, priv, nil, nil), pub)
		if err != nil {
			t.Fatal(err)
		}
		if !res.Info.Verified || len(res.Profiles) != 2 {
			t.Fatalf("verified = %v, profiles = %d", res.Info.Verified, len(res.Profiles))
		}
	})
	t.Run("no key set: the signature is not looked at", func(t *testing.T) {
		res, err := fetchWith(t, signedServer(t, priv, nil, nil), "")
		if err != nil {
			t.Fatal(err)
		}
		if res.Info.Verified {
			t.Error("nothing was verified")
		}
	})
	t.Run("unsigned", func(t *testing.T) {
		if _, err := fetchWith(t, signedServer(t, nil, nil, nil), pub); !errors.Is(err, ErrUnsigned) {
			t.Fatalf("error = %v, want ErrUnsigned", err)
		}
	})
	t.Run("wrong key", func(t *testing.T) {
		if _, err := fetchWith(t, signedServer(t, priv, nil, nil), otherPub); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("changed body", func(t *testing.T) {
		srv := signedServer(t, priv, nil, func(_ http.Header, body []byte) []byte {
			evil := base64.StdEncoding.EncodeToString([]byte("trojan://pw@evil.example.com:443#E"))
			return []byte(evil)
		})
		if _, err := fetchWith(t, srv, pub); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("changed order", func(t *testing.T) {
		srv := signedServer(t, priv, map[string]string{OrderHeader: "vless-reality,trojan"}, func(h http.Header, body []byte) []byte {
			h.Set(OrderHeader, "trojan,vless-reality") // a header changed after signing (headers are written with the body)
			return body
		})
		// The test server sends the headers it has when the body is written, so the change reaches the client.
		if _, err := fetchWith(t, srv, pub); !errors.Is(err, ErrBadSignature) {
			t.Fatalf("error = %v, want ErrBadSignature", err)
		}
	})
	t.Run("bad key", func(t *testing.T) {
		if _, err := fetchWith(t, signedServer(t, priv, nil, nil), "not a key"); !errors.Is(err, ErrBadKey) {
			t.Fatalf("error = %v, want ErrBadKey", err)
		}
	})
}

func TestProtocolOrderOnlyFromVerifiedAnswers(t *testing.T) {
	priv, pub := keyPair(t)
	order := map[string]string{OrderHeader: "Vless-Reality, hysteria2", OrderHeader + "-IR": "trojan"}

	res, err := fetchWith(t, signedServer(t, priv, order, nil), pub)
	if err != nil {
		t.Fatal(err)
	}
	want := map[string][]string{"": {"vless-reality", "hysteria2"}, "IR": {"trojan"}}
	if len(res.Info.ProtocolOrder) != 2 || res.Info.ProtocolOrder[""][0] != want[""][0] || res.Info.ProtocolOrder[""][1] != want[""][1] ||
		res.Info.ProtocolOrder["IR"][0] != "trojan" {
		t.Fatalf("order = %v, want %v", res.Info.ProtocolOrder, want)
	}

	// The same headers on an answer nobody checked are ignored.
	res, err = fetchWith(t, signedServer(t, nil, order, nil), "")
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
