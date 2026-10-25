package store

import (
	"slices"
	"strings"
	"testing"
)

func TestNewServerHasASigningKey(t *testing.T) {
	s := Open(t.TempDir())
	st, err := Init(s, InitOptions{PublicHost: "203.0.113.7"})
	if err != nil {
		t.Fatal(err)
	}
	if st.Server.Subscription.SigningPublic() == "" {
		t.Fatal("a new server should sign its subscription")
	}
}

// A state made before subscriptions were signed gets a key when it is loaded, and keeps it afterwards.
func TestOldStateGetsASigningKey(t *testing.T) {
	s := Open(t.TempDir())
	if _, err := Init(s, InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	if err := s.Update(func(st *State) error { st.Server.Subscription.SigningKey = ""; return nil }); err != nil {
		t.Fatal(err)
	}
	st, err := s.Load()
	if err != nil {
		t.Fatal(err)
	}
	first := st.Server.Subscription.SigningPublic()
	if first == "" {
		t.Fatal("the state should have got a signing key")
	}
	st, _ = s.Load()
	if st.Server.Subscription.SigningPublic() != first {
		t.Fatal("the key should not change on every load")
	}
	if err := s.Update(func(st *State) error { return st.RotateSigningKey() }); err != nil {
		t.Fatal(err)
	}
	st, _ = s.Load()
	if st.Server.Subscription.SigningPublic() == first {
		t.Fatal("rotating should make a new key")
	}
}

func TestParseProtocolOrder(t *testing.T) {
	got, err := ParseProtocolOrder(" VLESS, hysteria2 ,,trojan")
	if err != nil || !slices.Equal(got, []string{"vless", "hysteria2", "trojan"}) {
		t.Fatalf("got %v, %v", got, err)
	}
	if got, err := ParseProtocolOrder(""); err != nil || len(got) != 0 {
		t.Fatalf("empty: %v, %v", got, err)
	}
	for _, bad := range []string{"vless,carrier-pigeon", "vless,vless"} {
		if _, err := ParseProtocolOrder(bad); err == nil {
			t.Errorf("%q should be refused", bad)
		} else if strings.TrimSpace(err.Error()) == "" {
			t.Errorf("%q: empty error", bad)
		}
	}
}
