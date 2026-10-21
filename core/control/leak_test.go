package control

import (
	"sync"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/leakcheck"
)

// A UI that connects and disconnects over and over (the desktop app does on
// every restart, and a flaky socket does it constantly) must not leave a
// goroutine or buffer behind per connection.
func TestClientChurnDoesNotLeak(t *testing.T) {
	s, addr := newTestServer(t, ServerConfig{Grace: -1})
	round := func(n int) {
		for i := 0; i < n; i++ {
			c, err := Dial(t.Context(), addr, s.Token())
			if err != nil {
				t.Fatal(err)
			}
			if err := c.Call(t.Context(), "ping", nil, nil); err != nil {
				t.Fatal(err)
			}
			c.Close()
		}
	}
	round(20) // warm-up
	before := leakcheck.Take(2 * time.Second)
	n := 300
	if testing.Short() {
		n = 60
	}
	round(n)
	after := leakcheck.Take(5 * time.Second)
	leakcheck.Check(t, "control client churn", n, before, after, leakcheck.Limits{Goroutines: 3, HeapBytes: 8 << 20})
}

// Every request runs in its own goroutine; a burst of them must all finish and
// leave nothing behind, and the connection must keep answering afterwards.
func TestRequestBurstDoesNotLeak(t *testing.T) {
	s, addr := newTestServer(t, ServerConfig{Grace: -1})
	c, err := Dial(t.Context(), addr, s.Token())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	burst := func(n, workers int) {
		var wg sync.WaitGroup
		for w := 0; w < workers; w++ {
			wg.Go(func() {
				for i := 0; i < n/workers; i++ {
					if err := c.Call(t.Context(), "state", nil, nil); err != nil {
						t.Error(err)
						return
					}
				}
			})
		}
		wg.Wait()
	}
	burst(200, 8) // warm-up
	before := leakcheck.Take(2 * time.Second)
	n := 4000
	if testing.Short() {
		n = 800
	}
	start := time.Now()
	burst(n, 32)
	t.Logf("%d state requests from 32 callers took %v", n, time.Since(start))
	after := leakcheck.Take(5 * time.Second)
	leakcheck.Check(t, "control request burst", n, before, after, leakcheck.Limits{Goroutines: 3, HeapBytes: 8 << 20})
	if err := c.Call(t.Context(), "ping", nil, nil); err != nil {
		t.Fatalf("connection stopped answering after the burst: %v", err)
	}
}

// Benchmarks the request path (read, dispatch goroutine, encode, write) on one connection.
func BenchmarkPing(b *testing.B) {
	s, addr := newTestServer(b, ServerConfig{Grace: -1})
	c, err := Dial(b.Context(), addr, s.Token())
	if err != nil {
		b.Fatal(err)
	}
	defer c.Close()
	b.ReportAllocs()
	for b.Loop() {
		if err := c.Call(b.Context(), "ping", nil, nil); err != nil {
			b.Fatal(err)
		}
	}
}
