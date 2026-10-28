package logs

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fill writes records until the current file is near its rotation size.
func fill(b *testing.B, dir string) {
	b.Helper()
	l := Open(dir)
	l.SetLevel(LevelTrace)
	defer l.Close()
	for i := range 40000 {
		l.Write("info", fmt.Sprintf("inbound/trojan[%d]: connection from 203.0.113.%d:%d", i%7, i%250, 1024+i%60000))
	}
}

// fillText writes the plain text lines of older servers.
func fillText(b *testing.B, dir string) {
	b.Helper()
	var out strings.Builder
	for i := range 40000 {
		fmt.Fprintf(&out, "%s INFO  inbound/trojan[%d]: connection from 203.0.113.%d:%d\n",
			time.Date(2026, 10, 16, 18, 0, 0, 0, time.Local).Format("2006-01-02 15:04:05"), i%7, i%250, 1024+i%60000)
	}
	if err := os.WriteFile(filepath.Join(dir, fileName), []byte(out.String()), 0o600); err != nil {
		b.Fatal(err)
	}
}

// Tail reads the end of the file (and the rotated one) for every request of
// the API's /logs and the TUI's log view.
func BenchmarkTail(b *testing.B) {
	dir := b.TempDir()
	fill(b, dir)
	b.ReportAllocs()
	for b.Loop() {
		records, err := Tail(dir, 200)
		if err != nil || len(records) != 200 {
			b.Fatalf("Tail: %d records, %v", len(records), err)
		}
	}
}

// BenchmarkTailText reads a log of the older text format.
func BenchmarkTailText(b *testing.B) {
	dir := b.TempDir()
	fillText(b, dir)
	b.ReportAllocs()
	for b.Loop() {
		records, err := Tail(dir, 200)
		if err != nil || len(records) != 200 {
			b.Fatalf("Tail: %d records, %v", len(records), err)
		}
	}
}

// BenchmarkQueryErrors looks for the last errors in a log of info records:
// the worst case, every line is looked at.
func BenchmarkQueryErrors(b *testing.B) {
	dir := b.TempDir()
	fill(b, dir)
	b.ReportAllocs()
	for b.Loop() {
		if _, err := Query(dir, Filter{Level: LevelError, Limit: 200}); err != nil {
			b.Fatal(err)
		}
	}
}

// Write takes the log's lock and does one write per record.
func BenchmarkWrite(b *testing.B) {
	l := Open(b.TempDir())
	l.SetLevel(LevelTrace)
	defer l.Close()
	b.ReportAllocs()
	for b.Loop() {
		l.Write("info", "inbound/trojan[0]: connection from 203.0.113.9:40000")
	}
}

// BenchmarkWriteRecord writes a record with context keys.
func BenchmarkWriteRecord(b *testing.B) {
	l := Open(b.TempDir())
	l.SetLevel(LevelTrace)
	defer l.Close()
	b.ReportAllocs()
	for b.Loop() {
		l.Log(LevelError, Record{Msg: "trojan did not start", Target: "trojan", Op: "start", Code: "START_FAILED", Err: "listen tcp: address already in use"})
	}
}

// A level that is off costs nothing.
func BenchmarkWriteFiltered(b *testing.B) {
	l := Open(b.TempDir())
	l.SetLevel(LevelError)
	defer l.Close()
	b.ReportAllocs()
	for b.Loop() {
		l.Write("info", "inbound/trojan[0]: connection from 203.0.113.9:40000")
	}
}
