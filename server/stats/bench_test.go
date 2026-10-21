package stats

import (
	"fmt"
	"testing"
)

func benchTracker(b *testing.B, users int) *Tracker {
	b.Helper()
	t := NewTracker(b.TempDir())
	live := map[string]Live{}
	for i := range users {
		name := fmt.Sprintf("user%04d", i)
		t.Add(name, int64(i)*1000, int64(i)*3000)
		if i%10 == 0 {
			live[name] = Live{Connections: 2, UpBps: 1000, DownBps: 5000}
		}
	}
	t.SetLive(live)
	return t
}

// Save runs every 10 seconds on a running server: JSON of every user, then a
// write and a rename.
func BenchmarkSave(b *testing.B) {
	for _, users := range []int{10, 200, 2000} {
		b.Run(fmt.Sprintf("users=%d", users), func(b *testing.B) {
			t := benchTracker(b, users)
			b.ReportAllocs()
			for b.Loop() {
				if err := t.Save(); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}

// SetLive runs on every 2-second tick under the tracker's lock.
func BenchmarkSetLive(b *testing.B) {
	for _, users := range []int{10, 200, 2000} {
		b.Run(fmt.Sprintf("users=%d", users), func(b *testing.B) {
			t := benchTracker(b, users)
			live := map[string]Live{}
			for i := 0; i < users; i += 5 {
				live[fmt.Sprintf("user%04d", i)] = Live{Connections: 1, UpBps: 10, DownBps: 20}
			}
			b.ReportAllocs()
			for b.Loop() {
				t.SetLive(live)
			}
		})
	}
}

// Add runs for every traffic event of every connection.
func BenchmarkAdd(b *testing.B) {
	t := benchTracker(b, 200)
	b.ReportAllocs()
	for b.Loop() {
		t.Add("user0042", 1500, 9000)
	}
}
