package logrec

import (
	"bytes"
	"encoding/json"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/buildinfo"
)

// countingArg counts how often a message argument is formatted.
type countingArg struct{ formatted *atomic.Int32 }

func (c countingArg) String() string {
	c.formatted.Add(1)
	return "arg"
}

func TestLevelGate(t *testing.T) {
	t.Cleanup(ResetLevel)
	SetLevel(LevelError, time.Time{})
	if Enabled(LevelWarn) || !Enabled(LevelError) || !Enabled(LevelFatal) {
		t.Fatalf("error level: warn %v error %v fatal %v", Enabled(LevelWarn), Enabled(LevelError), Enabled(LevelFatal))
	}
	var out bytes.Buffer
	logger := NewLogger(&out, SourceCore)
	var formatted atomic.Int32
	logger.Logf(LevelDebug, "value %v", countingArg{&formatted})
	if formatted.Load() != 0 || out.Len() != 0 {
		t.Fatalf("a level that is off formatted its message (%d) or wrote %q", formatted.Load(), out.String())
	}
	logger.Logf(LevelError, "value %v", countingArg{&formatted})
	if formatted.Load() != 1 || !strings.Contains(out.String(), `"msg":"value arg"`) {
		t.Fatalf("formatted %d, wrote %q", formatted.Load(), out.String())
	}
	if strings.Contains(out.String(), `"caller"`) {
		t.Fatalf("caller at error level: %s", out.String())
	}
	SetLevel(LevelDebug, time.Time{})
	out.Reset()
	logger.Logf(LevelDebug, "here")
	if !strings.Contains(out.String(), `"caller":"logrec/logrec_test.go:`) {
		t.Fatalf("no caller at debug level: %s", out.String())
	}
}

func TestParseLevel(t *testing.T) {
	for name, want := range map[string]Level{"trace": LevelTrace, "DEBUG": LevelDebug, "info": LevelInfo, "warning": LevelWarn, "error": LevelError, "panic": LevelFatal} {
		if got, ok := ParseLevel(name); !ok || got != want {
			t.Errorf("ParseLevel(%q) = %v, %v", name, got, ok)
		}
	}
	if _, ok := ParseLevel("loud"); ok {
		t.Error("ParseLevel accepted an unknown level")
	}
	if !(LevelTrace < LevelDebug && LevelDebug < LevelInfo && LevelInfo < LevelWarn && LevelWarn < LevelError && LevelError < LevelFatal) {
		t.Error("levels out of order")
	}
}

func TestDefaultLevelFollowsBuildMode(t *testing.T) {
	t.Cleanup(ResetLevel)
	if DefaultLevel() != LevelDebug {
		t.Fatalf("dev build default = %v", DefaultLevel())
	}
	// buildinfo.Mode is set by -ldflags; the default is read from it whenever the level is reset.
	setMode(t, "release")
	ResetLevel()
	if DefaultLevel() != LevelError || Current() != LevelError {
		t.Fatalf("release default = %v, current %v", DefaultLevel(), Current())
	}
}

func TestSetLevelUntilReverts(t *testing.T) {
	t.Cleanup(ResetLevel)
	SetLevel(LevelTrace, time.Now().Add(50*time.Millisecond))
	if level, until, set := Get(); level != LevelTrace || until.IsZero() || !set {
		t.Fatalf("Get = %v %v %v", level, until, set)
	}
	deadline := time.Now().Add(2 * time.Second)
	for Current() != DefaultLevel() {
		if time.Now().After(deadline) {
			t.Fatalf("level still %v after until", Current())
		}
		time.Sleep(10 * time.Millisecond)
	}
	if _, until, set := Get(); !until.IsZero() || set {
		t.Fatalf("after revert: until %v, set %v", until, set)
	}
	// A later change cancels the pending revert of an earlier one.
	SetLevel(LevelInfo, time.Now().Add(30*time.Millisecond))
	SetLevel(LevelWarn, time.Time{})
	time.Sleep(80 * time.Millisecond)
	if Current() != LevelWarn {
		t.Fatalf("an old until reverted a newer level: %v", Current())
	}
}

func TestRecordJSON(t *testing.T) {
	rec := Record{
		Time:  time.Date(2026, 10, 29, 1, 2, 3, 456_000_000, time.FixedZone("x", 3600)),
		Level: LevelError, Source: SourceTor, Msg: "bootstrap stalled", Op: "connect", Conn: "7f3a", Profile: "p_19",
		Code: "TOR_TIMEOUT", Err: "timed out", Notify: true,
		Extra: map[string]any{"kind": "guard", "max": 3, "msg": "ignored"},
	}
	got, err := json.Marshal(rec)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"time":"2026-10-29T00:02:03.456Z","level":"error","source":"tor","msg":"bootstrap stalled","op":"connect",` +
		`"conn":"7f3a","profile":"p_19","code":"TOR_TIMEOUT","err":"timed out","notify":true,"kind":"guard","max":3}`
	if string(got) != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
	var back Record
	if err := json.Unmarshal(got, &back); err != nil {
		t.Fatal(err)
	}
	if !back.Time.Equal(rec.Time) || back.Level != LevelError || back.Conn != "7f3a" || !back.Notify || back.Extra["kind"] != "guard" || back.Extra["max"] != 3.0 {
		t.Fatalf("round trip: %+v", back)
	}
	// Optional keys are left out, the required ones are always there.
	got, _ = json.Marshal(Record{Time: rec.Time, Level: LevelInfo})
	if string(got) != `{"time":"2026-10-29T00:02:03.456Z","level":"info","source":"","msg":""}` {
		t.Fatalf("minimal record: %s", got)
	}
}

func TestDedupe(t *testing.T) {
	first := Record{Conn: "c1", Code: "TOR_EXITED", Notify: true}
	Dedupe(&first)
	again := Record{Conn: "c1", Code: "TOR_EXITED", Notify: true}
	Dedupe(&again)
	other := Record{Conn: "c1", Code: "ENGINE_FATAL", Notify: true}
	Dedupe(&other)
	nextAttempt := Record{Conn: "c2", Code: "TOR_EXITED", Notify: true}
	Dedupe(&nextAttempt)
	if !first.Notify || again.Notify || !other.Notify || !nextAttempt.Notify {
		t.Fatalf("notify: first %v again %v other code %v other conn %v", first.Notify, again.Notify, other.Notify, nextAttempt.Notify)
	}
}

func TestRecover(t *testing.T) {
	Repanic = false
	t.Cleanup(func() { Repanic = true })
	got := make(chan Record, 1)
	go func() {
		defer Recover(SourceCore, "connect", func(rec Record) { got <- rec })
		var profiles map[string]int
		profiles["x"] = 1 //nolint:staticcheck // SA5000: the panic is the test // a nil map write panics
	}()
	select {
	case rec := <-got:
		if rec.Level != LevelFatal || !rec.Notify || rec.Code != CodePanic || rec.Op != "connect" ||
			!strings.Contains(rec.Stack, "TestRecover") || !strings.HasPrefix(rec.Caller, "logrec/logrec_test.go:") ||
			!strings.Contains(rec.Msg, "nil map") {
			t.Fatalf("panic record: %+v", rec)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no panic record")
	}
}

func TestScrub(t *testing.T) {
	for in, want := range map[string]string{
		"dial tcp 192.0.2.1:443: i/o timeout":                     "dial tcp [addr]: i/o timeout",
		"dial tcp [2001:db8::1]:443: connection refused":          "dial tcp [addr]: connection refused",
		"lookup vpn.example.com: no such host":                    "lookup [host]: no such host",
		"Get \"https://sub.example.org/x?token=abc\": EOF":        "Get \"[url]\": EOF",
		"bad bridge line \"obfs4 192.0.2.3:80 ABCD cert=xyz+/=\"": "bad bridge line \"obfs4 [addr] ABCD cert=[redacted]\"",
		"user 0b3e5f2a-1c2d-4e5f-8a9b-0c1d2e3f4a5b rejected":      "user [uuid] rejected",
		"to 2001:db8:0:0:0:0:0:1 via fe80::1%eth0":                "to [addr] via [addr]%eth0",
		"context.Canceled at 01:02:03 in engine.go":               "context.Canceled at 01:02:03 in engine.go",
		"Tor attempt 2/3 failed":                                  "Tor attempt 2/3 failed",
	} {
		if got := Scrub(in); got != want {
			t.Errorf("Scrub(%q)\n got  %q\n want %q", in, got, want)
		}
	}
}

// setMode changes the build mode for one test.
func setMode(t *testing.T, mode string) {
	old := buildinfo.Mode
	buildinfo.Mode = mode
	t.Cleanup(func() {
		buildinfo.Mode = old
		ResetLevel()
	})
}
