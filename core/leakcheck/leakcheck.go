// Package leakcheck is for tests that start and stop something many times and
// must end where they began: no goroutines left behind, no heap that keeps
// growing. It is only imported by tests.
package leakcheck

import (
	"bytes"
	"runtime"
	"runtime/pprof"
	"testing"
	"time"
)

// Snapshot is the process state a cycle test compares.
type Snapshot struct {
	Goroutines int
	HeapInuse  uint64 // bytes in use after a forced GC
}

// Take forces a GC and returns the current numbers. It waits up to settle for
// the goroutine count to stop falling, because goroutines that were told to
// stop take a moment to return.
func Take(settle time.Duration) Snapshot {
	deadline := time.Now().Add(settle)
	n := runtime.NumGoroutine()
	for time.Now().Before(deadline) {
		time.Sleep(50 * time.Millisecond)
		m := runtime.NumGoroutine()
		if m >= n {
			break
		}
		n = m
	}
	runtime.GC()
	runtime.GC() // a second pass frees what finalizers released
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	return Snapshot{Goroutines: runtime.NumGoroutine(), HeapInuse: ms.HeapInuse}
}

// Limits are what a cycle test tolerates.
type Limits struct {
	Goroutines int    // extra goroutines allowed after the cycles
	HeapBytes  uint64 // extra in-use heap allowed after the cycles
}

// Check logs the before and after numbers and fails the test when the growth
// is over limits, with the goroutine stacks to find the culprit.
func Check(t *testing.T, what string, cycles int, before, after Snapshot, lim Limits) {
	t.Helper()
	dg := after.Goroutines - before.Goroutines
	dh := int64(after.HeapInuse) - int64(before.HeapInuse) //nolint:gosec // G115: heap sizes are far below 2^63
	t.Logf("%s, %d cycles: goroutines %d -> %d (%+d), heap in use %.1f -> %.1f MiB (%+.1f MiB, %.0f KiB/cycle)",
		what, cycles, before.Goroutines, after.Goroutines, dg,
		mib(before.HeapInuse), mib(after.HeapInuse), float64(dh)/(1<<20), float64(dh)/1024/float64(cycles))
	if dg > lim.Goroutines {
		var buf bytes.Buffer
		_ = pprof.Lookup("goroutine").WriteTo(&buf, 1)
		t.Errorf("%s: %d goroutines left behind after %d cycles (allowed %d):\n%s", what, dg, cycles, lim.Goroutines, buf.String())
	}
	if dh > 0 && uint64(dh) > lim.HeapBytes {
		t.Errorf("%s: heap grew %.1f MiB over %d cycles (allowed %.1f MiB)", what, float64(dh)/(1<<20), cycles, mib(lim.HeapBytes))
	}
}

func mib(b uint64) float64 { return float64(b) / (1 << 20) }
