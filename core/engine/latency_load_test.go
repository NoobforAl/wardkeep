//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"context"
	"os"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/profile"
)

// "Test all" in the app sends one TestLatency per server, all at once; each builds a
// temporary sing-box instance. This measures what that costs in memory and goroutines at
// its peak, for different numbers running at the same time. Opt-in (OMNITUN_LEAK=1): it
// waits for unreachable servers.
func TestLatencyConcurrencyCost(t *testing.T) {
	if os.Getenv("OMNITUN_LEAK") == "" {
		t.Skip("set OMNITUN_LEAK=1 to run the latency load measurement")
	}
	base := leakProfiles(t)
	const servers = 32
	var profiles []*profile.Profile
	for i := range servers {
		cp := *base[i%len(base)]
		cp.ID = ""
		cp.Name = cp.Name + "-" + itoa(i)
		cp.EnsureID()
		profiles = append(profiles, &cp)
	}
	e := New(Config{DataDir: tempDir(t), SkipHandshake: true})

	run := func(inParallel int) (peakHeapMiB float64, peakGoroutines int, took time.Duration) {
		runtime.GC()
		var peakHeap atomic.Uint64
		var peakG atomic.Int64
		stop := make(chan struct{})
		var sampler sync.WaitGroup
		sampler.Go(func() {
			var ms runtime.MemStats
			for {
				select {
				case <-stop:
					return
				case <-time.After(20 * time.Millisecond):
				}
				runtime.ReadMemStats(&ms)
				if ms.HeapInuse > peakHeap.Load() {
					peakHeap.Store(ms.HeapInuse)
				}
				if g := int64(runtime.NumGoroutine()); g > peakG.Load() {
					peakG.Store(g)
				}
			}
		})
		start := time.Now()
		sem := make(chan struct{}, inParallel)
		var wg sync.WaitGroup
		for _, p := range profiles {
			sem <- struct{}{}
			wg.Go(func() {
				defer func() { <-sem }()
				ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
				defer cancel()
				e.TestLatency(ctx, []*profile.Profile{p}, "")
			})
		}
		wg.Wait()
		took = time.Since(start)
		close(stop)
		sampler.Wait()
		return float64(peakHeap.Load()) / (1 << 20), int(peakG.Load()), took
	}

	run(4) // warm-up
	for _, n := range []int{servers, 8, 4, 2} {
		heap, g, took := run(n)
		t.Logf("%d servers, %2d at a time: peak heap in use %6.1f MiB, peak goroutines %5d, took %v", servers, n, heap, g, took.Round(100*time.Millisecond))
	}
}
