package runtime

import (
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/leakcheck"
)

// Every user change makes the server stop and rebuild its listeners. A server
// that runs for months and reloads on each of them must not collect
// goroutines, accounting collectors or file handles.
func TestReloadDoesNotLeak(t *testing.T) {
	_, srv := setup(t)
	for range 3 { // warm-up
		if err := srv.Reload(); err != nil {
			t.Fatal(err)
		}
	}
	before := leakcheck.Take(3 * time.Second)
	n := 30
	if testing.Short() {
		n = 8
	}
	for i := range n {
		if err := srv.Reload(); err != nil {
			t.Fatalf("reload %d: %v", i, err)
		}
	}
	after := leakcheck.Take(5 * time.Second)
	leakcheck.Check(t, "server reload", n, before, after, leakcheck.Limits{Goroutines: 4, HeapBytes: 24 << 20})
}
