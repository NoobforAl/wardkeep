package logs

import (
	"fmt"
	"testing"
)

// fill writes lines until the current file is near its rotation size.
func fill(b *testing.B, dir string) {
	b.Helper()
	l := Open(dir)
	defer l.Close()
	for i := 0; i < 40000; i++ {
		l.Write("info", fmt.Sprintf("inbound/trojan[%d]: connection from 203.0.113.%d:%d", i%7, i%250, 1024+i%60000))
	}
}

// Tail reads the whole file (and the rotated one) for every request of the
// API's /logs and the TUI's log view.
func BenchmarkTail(b *testing.B) {
	dir := b.TempDir()
	fill(b, dir)
	b.ReportAllocs()
	for b.Loop() {
		lines, err := Tail(dir, 200)
		if err != nil || len(lines) != 200 {
			b.Fatalf("Tail: %d lines, %v", len(lines), err)
		}
	}
}

// Write takes the log's lock and does one write per line.
func BenchmarkWrite(b *testing.B) {
	l := Open(b.TempDir())
	defer l.Close()
	b.ReportAllocs()
	for b.Loop() {
		l.Write("info", "inbound/trojan[0]: connection from 203.0.113.9:40000")
	}
}
