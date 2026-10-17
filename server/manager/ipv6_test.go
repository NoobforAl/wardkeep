package manager

import (
	"slices"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/server/store"
)

// IPv6 in the tunnels is off for a new server; switching it on adds an address to the WireGuard
// config the server hands out, and off takes it away again.
func TestSwitchingIPv6(t *testing.T) {
	m := newManager(t)
	if _, err := m.AddUser(NewUser{Name: "alice"}); err != nil {
		t.Fatal(err)
	}
	addresses := func() []string {
		_, conf, err := m.File("alice", store.WireGuardKey)
		if err != nil {
			t.Fatal(err)
		}
		res, err := importer.Import(conf)
		if err != nil || len(res.Profiles) != 1 {
			t.Fatalf("%v\n%s", err, conf)
		}
		return res.Profiles[0].WireGuard.Address
	}
	if info, _ := m.Server(); info.IPv6 {
		t.Fatal("a new server has IPv6 on")
	}
	if a := addresses(); len(a) != 1 || strings.Contains(a[0], ":") {
		t.Fatalf("addresses with IPv6 off: %v", a)
	}
	info, err := m.SetIPv6(true)
	if err != nil || !info.IPv6 {
		t.Fatalf("on: %+v %v", info, err)
	}
	if a := addresses(); len(a) != 2 || !strings.HasPrefix(a[0], "10.30.") || !strings.HasPrefix(a[1], "fd30:") {
		t.Fatalf("addresses with IPv6 on: %v", a)
	}
	if got, _ := m.Server(); !got.IPv6 {
		t.Fatal("the setting was not kept")
	}
	if _, err := m.SetIPv6(false); err != nil {
		t.Fatal(err)
	}
	if a := addresses(); !slices.Equal(a, []string{a[0]}) || strings.Contains(a[0], ":") {
		t.Fatalf("addresses after switching off: %v", a)
	}
}
