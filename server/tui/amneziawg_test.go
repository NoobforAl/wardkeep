package tui

import (
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/server/store"
)

// On the Protocols tab, v switches AmneziaWG between 2.0 and 1.x, and the list
// shows which one the server has; on any other protocol it does nothing.
func TestTUISwitchesTheAmneziaWGVersion(t *testing.T) {
	m, mgr := newTestModel(t)
	at := -1
	for i, p := range m.protos {
		if p.Key == store.AmneziaWGKey {
			at = i
		}
	}
	if at < 0 {
		t.Fatal("no amneziawg in the list")
	}
	version := func() string {
		list, _ := mgr.Protocols()
		return list[at].AmneziaWGVersion
	}
	send(m, "2", "v") // the cursor is on the first protocol
	if version() != "2.0" {
		t.Fatal("v on another protocol changed AmneziaWG")
	}
	for range at {
		send(m, "down")
	}
	if !strings.Contains(m.View(), "udp · 2.0") {
		t.Fatalf("the list does not show the version:\n%s", m.View())
	}
	send(m, "v")
	if version() != "1.x" || m.err != nil {
		t.Fatalf("after v: %q (tui error: %v)", version(), m.err)
	}
	if !strings.Contains(m.View(), "udp · 1.x") {
		t.Fatalf("the list does not show 1.x:\n%s", m.View())
	}
	send(m, "v")
	if version() != "2.0" {
		t.Fatalf("after v again: %q", version())
	}
}
