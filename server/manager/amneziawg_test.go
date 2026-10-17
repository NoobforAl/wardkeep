package manager

import (
	"errors"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/awg"
	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/server/store"
)

func awgLink(t *testing.T, m *Manager, user string) string {
	t.Helper()
	set, err := m.Links(user)
	if err != nil {
		t.Fatal(err)
	}
	for _, l := range set.Links {
		if l.Protocol == store.AmneziaWGKey {
			return l.URL
		}
	}
	t.Fatalf("no amneziawg link in %+v", set.Links)
	return ""
}

func awgParams(t *testing.T, link string) map[string]string {
	t.Helper()
	res, err := importer.Import(link)
	if err != nil || len(res.Profiles) != 1 {
		t.Fatalf("import %s: %v", link, err)
	}
	return res.Profiles[0].WireGuard.Amnezia
}

func awgVersionOf(t *testing.T, m *Manager) string {
	t.Helper()
	list, err := m.Protocols()
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range list {
		if p.Key == store.AmneziaWGKey {
			return p.AmneziaWGVersion
		}
		if p.AmneziaWGVersion != "" {
			t.Fatalf("%s reports an AmneziaWG version", p.Key)
		}
	}
	t.Fatal("no amneziawg protocol")
	return ""
}

// A new server is AmneziaWG 2.0 and says so; its link carries the 2.0 keys; a
// classic server can be asked for at init.
func TestNewServerIsAmneziaWG2(t *testing.T) {
	m := newManager(t)
	on := true
	if _, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{Enabled: &on}); err != nil {
		t.Fatal(err)
	}
	if _, err := m.AddUser(NewUser{Name: "alice"}); err != nil {
		t.Fatal(err)
	}
	if v := awgVersionOf(t, m); v != store.AWG2 {
		t.Fatalf("a new server has AmneziaWG %s", v)
	}
	params := awgParams(t, awgLink(t, m, "alice"))
	if awg.Generation(params) != "2.0" || params["s3"] == "" || params["s4"] == "" || !strings.Contains(params["h1"], "-") {
		t.Fatalf("the link does not carry the 2.0 keys: %v", params)
	}
	if err := awg.CheckParams(params); err != nil {
		t.Fatal(err)
	}

	classic := New(store.Open(tempDir(t)))
	if _, err := classic.Init(InitOptions{PublicHost: "203.0.113.7", AmneziaWGVersion: "classic"}); err != nil {
		t.Fatal(err)
	}
	if v := awgVersionOf(t, classic); v != store.AWGClassic {
		t.Fatalf("init --awg-version classic gave AmneziaWG %s", v)
	}
	if _, err := New(store.Open(tempDir(t))).Init(InitOptions{PublicHost: "203.0.113.7", AmneziaWGVersion: "3.0"}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("a wrong version at init: %v", err)
	}
}

// Choosing the version of an existing interface makes new parameters and keeps
// the server's keys and users; choosing the version it has leaves it alone.
func TestSwitchingTheAmneziaWGVersion(t *testing.T) {
	m := newManager(t)
	on := true
	if _, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{Enabled: &on}); err != nil {
		t.Fatal(err)
	}
	if _, err := m.AddUser(NewUser{Name: "alice"}); err != nil {
		t.Fatal(err)
	}
	before, _ := m.Store.Load()
	was := awgParams(t, awgLink(t, m, "alice"))

	v2 := "2.0"
	if _, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{AmneziaWGVersion: &v2}); err != nil {
		t.Fatal(err)
	}
	if now := awgParams(t, awgLink(t, m, "alice")); !equalParams(now, was) {
		t.Fatalf("asking for the version it has changed the parameters:\nwas %v\nnow %v", was, now)
	}

	classic := "1.x"
	p, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{AmneziaWGVersion: &classic})
	if err != nil || p.AmneziaWGVersion != store.AWGClassic || !p.Enabled {
		t.Fatalf("switch to 1.x: %+v %v", p, err)
	}
	old := awgParams(t, awgLink(t, m, "alice"))
	if awg.Generation(old) != "1.x" || old["s3"] != "" || strings.Contains(old["h1"], "-") || len(old) != 9 {
		t.Fatalf("the 1.x link carries %v", old)
	}
	if err := awg.CheckParams(old); err != nil {
		t.Fatal(err)
	}
	after, _ := m.Store.Load()
	if after.Server.AmneziaWG.PublicKey != before.Server.AmneziaWG.PublicKey || after.Users[0].WGPublicKey != before.Users[0].WGPublicKey {
		t.Fatal("switching the version changed a key")
	}
	// Asking for 1.x again keeps the same 1.x parameters.
	if _, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{AmneziaWGVersion: &classic}); err != nil {
		t.Fatal(err)
	}
	if again := awgParams(t, awgLink(t, m, "alice")); !equalParams(again, old) {
		t.Fatalf("a repeated 1.x choice changed the parameters:\nwas %v\nnow %v", old, again)
	}

	if _, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{AmneziaWGVersion: &v2}); err != nil {
		t.Fatal(err)
	}
	if awg.Generation(awgParams(t, awgLink(t, m, "alice"))) != "2.0" || awgVersionOf(t, m) != store.AWG2 {
		t.Fatal("did not switch back to 2.0")
	}

	bad := "4.2"
	if _, err := m.SetProtocol(store.AmneziaWGKey, ProtocolPatch{AmneziaWGVersion: &bad}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("a wrong version: %v", err)
	}
	if _, err := m.SetProtocol(store.Trojan, ProtocolPatch{AmneziaWGVersion: &v2}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("a version for another protocol: %v", err)
	}
}

func equalParams(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}
