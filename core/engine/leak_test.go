//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/leakcheck"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// cycles is how many times the leak tests start and stop; OMNITUN_LEAK_CYCLES
// raises it for a longer soak.
func cycles(def int) int {
	if n, err := strconv.Atoi(os.Getenv("OMNITUN_LEAK_CYCLES")); err == nil && n > 0 {
		return n
	}
	if testing.Short() {
		return def / 4
	}
	return def
}

func leakProfiles(t *testing.T) []*profile.Profile {
	t.Helper()
	var out []*profile.Profile
	for _, link := range testLinks() {
		p, err := importer.ParseLink(link)
		if err != nil {
			t.Fatal(err)
		}
		out = append(out, p)
	}
	return out
}

// Starting and stopping the engine over and over (what the app does every time
// the user connects and disconnects) must not leave goroutines or heap behind.
//
// It takes about a minute, so it only runs with OMNITUN_LEAK=1. The tunnel gets
// OMNITUN_LEAK_SETTLE (default 2s) between start and stop so the urltest and DNS
// queries it begins with are over: stopping while they are in flight leaks one
// goroutine and a socket per cycle inside sing-box v1.14.3 (its UDP DNS
// transport is never closed with the box); OMNITUN_LEAK_SETTLE=0 shows it.
func TestStartStopDoesNotLeak(t *testing.T) {
	if os.Getenv("OMNITUN_LEAK") == "" {
		t.Skip("set OMNITUN_LEAK=1 to run the start/stop leak soak")
	}
	profiles := leakProfiles(t)
	settle := 2 * time.Second
	if v, err := time.ParseDuration(os.Getenv("OMNITUN_LEAK_SETTLE")); err == nil {
		settle = v
	}
	e := New(Config{DataDir: tempDir(t), SkipHandshake: true})
	cycle := func(i int) {
		// One server, then the whole group, alternating, so both the plain and the
		// selector/urltest paths are exercised.
		set := profiles
		if i%2 == 0 {
			set = profiles[i%len(profiles) : i%len(profiles)+1]
		}
		if err := e.Start(set, singbox.Options{ListenPort: freePort(t), LogLevel: "error"}); err != nil {
			t.Fatalf("cycle %d: start: %v", i, err)
		}
		time.Sleep(settle)
		if err := e.Stop(); err != nil {
			t.Fatalf("cycle %d: stop: %v", i, err)
		}
	}
	for i := 0; i < 5; i++ { // warm-up: first use allocates caches that stay
		cycle(i)
	}
	before := leakcheck.Take(3 * time.Second)
	n := cycles(20)
	for i := 0; i < n; i++ {
		cycle(i)
	}
	after := leakcheck.Take(5 * time.Second)
	leakcheck.Check(t, "engine start/stop", n, before, after, leakcheck.Limits{Goroutines: 4, HeapBytes: 24 << 20})
}

// The state callback runs while the engine lock is held; a callback that
// takes a long time (the Android one calls into the JVM) must not make
// State() or Stop() wait forever, and must not leak when it is slow.
func TestStartStopWithSlowStateCallback(t *testing.T) {
	profiles := leakProfiles(t)
	e := New(Config{DataDir: tempDir(t), SkipHandshake: true, OnState: func(State) {
		time.Sleep(20 * time.Millisecond)
	}})
	start := time.Now()
	n := cycles(12)
	for i := 0; i < n; i++ {
		if err := e.Start(profiles[:1], singbox.Options{ListenPort: freePort(t), LogLevel: "error"}); err != nil {
			t.Fatal(err)
		}
		_ = e.State()
		if err := e.Stop(); err != nil {
			t.Fatal(err)
		}
	}
	t.Logf("%d start/stop cycles with a 20 ms state callback took %v", n, time.Since(start))
}
