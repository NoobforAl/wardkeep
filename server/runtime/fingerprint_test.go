//go:build with_quic && with_utls && with_wireguard && with_gvisor

package runtime

import (
	"fmt"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/server/store"
)

// Changes the listeners never read (a note, a quota figure, the API settings) do not restart
// the server and so do not disconnect anyone; changes they do read (a user disabled, reset,
// a port) restart it.
func TestReloadOnlyWhenTheListenersChange(t *testing.T) {
	s, srv := setup(t)
	// instance names the running sing-box ("" when none), so a restart shows as a different name.
	instance := func() string {
		srv.mu.Lock()
		defer srv.mu.Unlock()
		if srv.instance == nil {
			return ""
		}
		return fmt.Sprintf("%p", srv.instance)
	}
	first := instance()
	if first == "" {
		t.Fatal("not running")
	}
	apply := func(change func(st *store.State)) {
		t.Helper()
		time.Sleep(20 * time.Millisecond) // the file's modification time moves
		if err := s.Update(func(st *store.State) error { change(st); return nil }); err != nil {
			t.Fatal(err)
		}
		srv.mu.Lock()
		changed := !s.ModTime().Equal(srv.loaded)
		srv.mu.Unlock()
		if !changed {
			t.Fatal("the test change did not touch the state file")
		}
		if err := srv.reloadIfNeeded(true); err != nil {
			t.Fatal(err)
		}
	}

	for name, change := range map[string]func(st *store.State){
		"a note":         func(st *store.State) { st.User("alice").Note = "phone" },
		"a quota figure": func(st *store.State) { st.User("alice").QuotaGB = 50 },
		"a usage reset":  func(st *store.State) { now := time.Now(); st.User("alice").UsageResetAt = &now },
		"the API token":  func(st *store.State) { st.Server.API.Token = "another-token" },
	} {
		apply(change)
		if instance() != first {
			t.Fatalf("%s restarted the server", name)
		}
		srv.mu.Lock()
		current := s.ModTime().Equal(srv.loaded)
		srv.mu.Unlock()
		if !current {
			t.Fatalf("%s: the file change was not marked as seen (it would be checked again every 2 seconds)", name)
		}
	}

	apply(func(st *store.State) { st.User("alice").Enabled = false })
	if instance() != "" {
		t.Fatal("disabling the only user did not restart the server")
	}
	apply(func(st *store.State) { st.User("alice").Enabled = true })
	second := instance()
	if second == "" || second == first {
		t.Fatal("enabling a user did not start the server again")
	}
	apply(func(st *store.State) { st.Server.Protocols[store.Trojan].Port = freeTCP(t) })
	if instance() == second || instance() == "" {
		t.Fatal("a port change did not restart the server")
	}
	apply(func(st *store.State) { st.User("alice").Password = "a-new-password" })
	if instance() == "" {
		t.Fatal("a reset left the server stopped")
	}
}
