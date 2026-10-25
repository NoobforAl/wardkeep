package serverconf

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/subscription"
	"github.com/NoobforAl/omnitun/server/store"
)

func signedSetup(t *testing.T) (s *store.Store, path, token string) {
	t.Helper()
	s = store.Open(t.TempDir())
	if _, err := store.Init(s, store.InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	if err := s.Update(func(st *store.State) error {
		u, err := store.AddUser(st, "alice")
		token, path = u.SubToken, st.Server.Subscription.Path
		return err
	}); err != nil {
		t.Fatal(err)
	}
	return s, path, token
}

func TestSubscriptionIsSigned(t *testing.T) {
	s, path, token := signedSetup(t)
	st, _ := s.Load()
	pub, err := subscription.ParseKey(st.Server.Subscription.SigningPublic())
	if err != nil {
		t.Fatalf("a new server has no usable signing key: %v", err)
	}

	for _, target := range []string{"", "?format=base64", "?format=sing-box", "/wireguard.conf"} {
		t.Run("answer "+target, func(t *testing.T) {
			rec := httptest.NewRecorder()
			SubscriptionHandler(s).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/"+path+"/"+token+target, nil))
			if rec.Code != 200 {
				t.Fatalf("status %d", rec.Code)
			}
			if err := subscription.Verify(pub, rec.Body.Bytes(), rec.Header()); err != nil {
				t.Fatalf("the answer does not verify: %v", err)
			}
			body := append([]byte("x"), rec.Body.Bytes()...)
			if err := subscription.Verify(pub, body, rec.Header()); err == nil {
				t.Fatal("a changed body should not verify")
			}
		})
	}
}

func TestSubscriptionProtocolOrderIsSigned(t *testing.T) {
	s, path, token := signedSetup(t)
	if err := s.Update(func(st *store.State) error {
		st.Server.Subscription.ProtocolOrder = map[string]string{"": "vless,hysteria2", "IR": "hysteria2"}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	st, _ := s.Load()
	pub, _ := subscription.ParseKey(st.Server.Subscription.SigningPublic())

	rec := httptest.NewRecorder()
	SubscriptionHandler(s).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/"+path+"/"+token+"?format=base64", nil))
	if got := rec.Header().Get("Protocol-Order"); got != "vless,hysteria2" {
		t.Fatalf("Protocol-Order = %q", got)
	}
	if got := rec.Header().Get("Protocol-Order-Ir"); got != "hysteria2" {
		t.Fatalf("Protocol-Order-IR = %q", got)
	}
	if err := subscription.Verify(pub, rec.Body.Bytes(), rec.Header()); err != nil {
		t.Fatalf("the answer does not verify: %v", err)
	}
	// Changing the order on the way breaks the signature.
	rec.Header().Set("Protocol-Order", "trojan")
	if err := subscription.Verify(pub, rec.Body.Bytes(), rec.Header()); err == nil {
		t.Fatal("a changed order should not verify")
	}
}

// The link a user is given carries the public key after #pk=; a client reads it and checks every answer.
func TestSubscriptionLinkCarriesTheKey(t *testing.T) {
	s, _, _ := signedSetup(t)
	st, _ := s.Load()
	u := st.User("alice")
	plain, link := SubscriptionURL(st, u), SubscriptionLink(st, u)
	if plain == "" || strings.Contains(plain, "#") {
		t.Fatalf("the plain URL = %q", plain)
	}
	parsed, err := url.Parse(link)
	if err != nil {
		t.Fatal(err)
	}
	pk, ok := strings.CutPrefix(parsed.Fragment, "pk=")
	if !ok || strings.ContainsAny(pk, "+/=%") || !strings.HasPrefix(link, plain+"#") {
		t.Fatalf("link = %q", link)
	}
	// What a client reads back is the signing key, in any base64 form it accepts.
	got, err := subscription.ParseKey(pk)
	want, _ := subscription.ParseKey(st.Server.Subscription.SigningPublic())
	if err != nil || !got.Equal(want) {
		t.Fatalf("the key in the link = %q (%v), want %q", pk, err, st.Server.Subscription.SigningPublic())
	}
	// Config file URLs are built from the plain URL, so they stay valid.
	if f := FileURL(st, u, "wireguard"); strings.Contains(f, "#") {
		t.Fatalf("file URL = %q", f)
	}
}
