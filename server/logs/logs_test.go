package logs

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/buildinfo"
)

func tempDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "omnitun-logs-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		for i := 0; i < 40 && os.RemoveAll(dir) != nil; i++ {
			time.Sleep(50 * time.Millisecond)
		}
	})
	return dir
}

// openAt opens a log at level with a fixed clock.
func openAt(dir string, level Level) *Log {
	l := Open(dir)
	l.SetLevel(level)
	l.now = func() time.Time { return time.Date(2026, 10, 16, 18, 0, 0, 123e6, time.UTC) }
	return l
}

func TestWriteAndTail(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelTrace)
	if records, err := Tail(dir, 10); err != nil || len(records) != 0 {
		t.Fatalf("empty log: %v %v", records, err)
	}
	l.Write("info", "started")
	l.Write("warn", "\x1b[31mcolour\x1b[0m and\nline breaks  ")
	l.Close()

	data, _ := os.ReadFile(filepath.Join(dir, fileName))
	want := `{"time":"2026-10-16T18:00:00.123Z","level":"info","source":"server","msg":"started"}` + "\n" +
		`{"time":"2026-10-16T18:00:00.123Z","level":"warn","source":"server","msg":"colour and line breaks"}` + "\n"
	if string(data) != want {
		t.Fatalf("file:\n%s\nwant:\n%s", data, want)
	}
	records, err := Tail(dir, 10)
	if err != nil || len(records) != 2 {
		t.Fatalf("records = %+v err %v", records, err)
	}
	if records[0].Msg != "started" || records[0].Level != "info" || records[1].Level != "warn" || records[1].Msg != "colour and line breaks" ||
		!records[0].Time.Equal(time.Date(2026, 10, 16, 18, 0, 0, 123e6, time.UTC)) || records[0].Source != "server" {
		t.Fatalf("records = %+v", records)
	}
	if last, _ := Tail(dir, 1); len(last) != 1 || last[0].Msg != "colour and line breaks" {
		t.Fatalf("tail 1 = %+v", last)
	}
	// A nil log is a valid no-op sink.
	var none *Log
	none.Write("info", "ignored")
	none.Log(LevelFatal, Record{Msg: "ignored"})
}

// Every record is valid JSON with the contract's keys, whatever its text holds.
func TestRecordsAreJSON(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelTrace)
	l.Log(LevelError, Record{
		Msg: `quote " backslash \ tab` + "\t" + `ünïcödé 日本`, Target: "inbound/trojan[trojan]", Op: "start", User: "alice",
		Code: "START_FAILED", Err: "listen: \x00\x01 bad \xff byte", Notify: true, Caller: "runtime.go:12",
		Stack: "goroutine 1 [running]:\n\tmain.main()\n", Extra: map[string]string{"profile": "p_1", "msg": "shadowed"},
	})
	l.Close()
	data, _ := os.ReadFile(filepath.Join(dir, fileName))
	var decoded map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("%v: %s", err, data)
	}
	for key, want := range map[string]any{
		"level": "error", "source": "server", "target": "inbound/trojan[trojan]", "op": "start", "user": "alice",
		"code": "START_FAILED", "notify": true, "caller": "runtime.go:12", "profile": "p_1",
		"msg": `quote " backslash \ tab ünïcödé 日本`, "err": "listen: bad � byte",
		"stack": "goroutine 1 [running]:\n    main.main()",
	} {
		if decoded[key] != want {
			t.Errorf("%s = %#v, want %#v", key, decoded[key], want)
		}
	}
	records, _ := Tail(dir, 1)
	got := records[0]
	if got.Msg != decoded["msg"] || got.Err != decoded["err"] || !got.Notify || got.Stack != decoded["stack"] || got.Extra["profile"] != "p_1" || got.User != "alice" {
		t.Fatalf("read back %+v", got)
	}
}

func TestLevelGate(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelError)
	l.Write("debug", "not kept")
	l.Write("info", "not kept")
	l.Log(LevelWarn, Record{Msg: "not kept"})
	l.Log(LevelError, Record{Msg: "kept"})
	l.Log(LevelFatal, Record{Msg: "kept too"})
	if l.Enabled(LevelInfo) || !l.Enabled(LevelError) {
		t.Fatal("Enabled")
	}
	l.SetLevel(LevelDebug)
	l.Write("debug", "kept now")
	l.Write("trace", "still not")
	l.Close()
	records, _ := Tail(dir, 10)
	var messages []string
	for _, rec := range records {
		messages = append(messages, rec.Msg)
	}
	if strings.Join(messages, ",") != "kept,kept too,kept now" {
		t.Fatalf("messages = %q", messages)
	}
}

func TestDefaultLevelFollowsTheBuild(t *testing.T) {
	saved := buildinfo.Mode
	defer func() { buildinfo.Mode = saved }()
	buildinfo.Mode = "release"
	if DefaultLevel() != LevelError || Open(t.TempDir()).Level() != LevelError {
		t.Fatal("release builds keep error and fatal")
	}
	buildinfo.Mode = "dev"
	if DefaultLevel() != LevelDebug {
		t.Fatal("dev builds keep debug")
	}
}

func TestParseLevel(t *testing.T) {
	for name, want := range map[string]Level{
		"trace": LevelTrace, "DEBUG": LevelDebug, "info": LevelInfo, "Warning": LevelWarn, "warn": LevelWarn,
		"error": LevelError, "fatal": LevelFatal, "panic": LevelFatal,
	} {
		if got, ok := ParseLevel(name); !ok || got != want {
			t.Errorf("ParseLevel(%q) = %v %v", name, got, ok)
		}
	}
	if _, ok := ParseLevel("loud"); ok {
		t.Error("an unknown level was accepted")
	}
}

func TestMirror(t *testing.T) {
	var out strings.Builder
	l := openAt(tempDir(t), LevelInfo)
	l.SetMirror(&out)
	l.Write("info", "to both")
	l.Write("debug", "to neither")
	l.Close()
	if !strings.HasSuffix(out.String(), `"msg":"to both"}`+"\n") || strings.Count(out.String(), "\n") != 1 {
		t.Fatalf("mirror = %q", out.String())
	}
}

func TestRotationKeepsTheNewestLines(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelTrace)
	defer l.Close()
	chunk := strings.Repeat("x", 1000)
	for i := range 5000 { // ~5 MB: rotates once
		l.Write("info", fmt.Sprintf("%05d %s", i, chunk))
	}
	if _, err := os.Stat(l.path() + ".1"); err != nil {
		t.Fatal("no rotated file")
	}
	fi, _ := os.Stat(l.path())
	if fi.Size() > maxSize {
		t.Fatalf("log is %d bytes", fi.Size())
	}
	records, err := Tail(dir, 3)
	if err != nil || len(records) != 3 || !strings.HasPrefix(records[2].Msg, "04999") || !strings.HasPrefix(records[0].Msg, "04997") {
		t.Fatalf("tail = %d records, err %v", len(records), err)
	}
	// Asking for more than the current file holds reads the rotated one.
	many, _ := Tail(dir, 4900)
	if len(many) != 4900 || !strings.HasPrefix(many[len(many)-1].Msg, "04999") || !strings.HasPrefix(many[0].Msg, "00100") {
		t.Fatalf("got %d records", len(many))
	}
}

// A name or header a client controls must not be able to drive the terminal
// of whoever reads the log.
func TestControlCharactersAreRemoved(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelTrace)
	esc := string(rune(27))
	hostile := "login failed for " + esc + "[2J" + esc + "]0;owned" + string(rune(7)) + " user\x08\x08\x08root" +
		"\u202e gnp.exe " + "a\u200bb " + string(rune(0x9b)) + "31m"
	l.Write("info", hostile)
	l.Log(LevelError, Record{Msg: "x", User: hostile, Err: hostile})
	l.Close()
	records, _ := Tail(dir, 2)
	if len(records) != 2 {
		t.Fatalf("records = %+v", records)
	}
	for _, text := range []string{records[0].Msg, records[1].User, records[1].Err} {
		for _, r := range text {
			if r < ' ' || r == 0x7f || (r >= 0x80 && r <= 0x9f) || r == 0x202e || r == 0x200b {
				t.Fatalf("control character %U survived: %q", r, text)
			}
		}
		if !strings.Contains(text, "login failed for") || !strings.Contains(text, "root") {
			t.Fatalf("the readable text was lost: %q", text)
		}
	}

	// A file written by something else is cleaned when read, in both formats.
	os.WriteFile(l.path(), []byte("2026-01-01 00:00:00 INFO  "+esc+"[31mred"+esc+"[0m\n"+
		`{"time":"2026-01-01T00:00:01Z","level":"info","source":"server","msg":"\u001b[2Jwipe","user":"\u0007bell"}`+"\n"), 0o600)
	records, _ = Tail(dir, 5)
	if len(records) != 2 || strings.ContainsAny(records[0].Msg+records[1].Msg+records[1].User, "\x1b\x07") ||
		records[0].Msg != "red" || records[1].Msg != "wipe" {
		t.Fatalf("read-side cleaning failed: %+v", records)
	}
}

// Logs written before the JSON records are still read, with their level.
func TestOldTextLines(t *testing.T) {
	dir := tempDir(t)
	os.WriteFile(filepath.Join(dir, fileName+".1"), []byte("2026-10-16 18:00:00 INFO  started\n"), 0o600)
	os.WriteFile(filepath.Join(dir, fileName), []byte(
		"2026-10-16 18:00:01 SING-BOX WARN inbound/trojan[trojan]: slow\n"+
			"2026-10-16 18:00:02 ERROR reload failed: x\n"+
			"no timestamp at all\n"+
			`{"time":"2026-10-16T16:00:03Z","level":"error","source":"server","msg":"json","code":"C","future":{"a":1},"n":3}`+"\n"), 0o600)
	records, err := Tail(dir, 10)
	if err != nil || len(records) != 5 {
		t.Fatalf("records = %+v %v", records, err)
	}
	local := func(sec int) time.Time { return time.Date(2026, 10, 16, 18, 0, sec, 0, time.Local) }
	checks := []struct {
		level, source, msg string
		at                 time.Time
	}{
		{"info", "server", "started", local(0)},
		{"warn", "sing-box", "inbound/trojan[trojan]: slow", local(1)},
		{"error", "server", "reload failed: x", local(2)},
		{"info", "server", "no timestamp at all", time.Time{}},
		{"error", "server", "json", time.Date(2026, 10, 16, 16, 0, 3, 0, time.UTC)},
	}
	for i, want := range checks {
		got := records[i]
		if got.Level != want.level || got.Source != want.source || got.Msg != want.msg || !got.Time.Equal(want.at) {
			t.Errorf("%d: %+v, want %+v", i, got, want)
		}
	}
	if records[4].Extra["future"] != `{"a":1}` || records[4].Extra["n"] != "3" || records[4].Code != "C" {
		t.Errorf("unknown keys: %+v", records[4].Extra)
	}
	if text := records[4].Text(); !strings.Contains(text, "ERROR json code=C future={\"a\":1} n=3") {
		t.Errorf("Text = %q", text)
	}
}

func TestQueryFilters(t *testing.T) {
	dir := tempDir(t)
	l := Open(dir)
	l.SetLevel(LevelTrace)
	start := time.Date(2026, 10, 16, 18, 0, 0, 0, time.UTC)
	clock := start
	l.now = func() time.Time { return clock }
	for i := range 100 {
		clock = start.Add(time.Duration(i) * time.Minute)
		level := []Level{LevelDebug, LevelInfo, LevelWarn, LevelError}[i%4]
		l.Log(level, Record{Msg: fmt.Sprint(i)})
	}
	l.Close()
	errors, _ := Query(dir, Filter{Level: LevelError, Limit: 5})
	if len(errors) != 5 || errors[0].Msg != "83" || errors[4].Msg != "99" {
		t.Fatalf("errors = %+v", errors)
	}
	recent, _ := Query(dir, Filter{Level: LevelWarn, Since: start.Add(90 * time.Minute), Limit: 100})
	var messages []string
	for _, rec := range recent {
		messages = append(messages, rec.Msg)
	}
	if strings.Join(messages, ",") != "90,91,94,95,98,99" {
		t.Fatalf("since = %q", messages)
	}
	if none, _ := Query(dir, Filter{Level: LevelFatal, Limit: 10}); len(none) != 0 {
		t.Fatalf("fatal = %+v", none)
	}
}

func TestScrub(t *testing.T) {
	for in, want := range map[string]string{
		"dial tcp 203.0.113.9:443: i/o timeout":         "dial tcp [address]: i/o timeout",
		"from [2001:db8::1]:5555 to example.com:443":    "from [address] to [address]",
		"peer 2001:db8::7 handshake":                    "peer [address] handshake",
		"at 12:30:45 nothing happened":                  "at 12:30:45 nothing happened",
		"no address here":                               "no address here",
		"lookup vpn.example.org:53 via 10.0.0.1 failed": "lookup [address] via [address] failed",
	} {
		if got := Scrub(in); got != want {
			t.Errorf("Scrub(%q) = %q, want %q", in, got, want)
		}
	}
	if got := HideDestinations("[alice] inbound connection to example.com:443"); got != "[alice] inbound connection to [destination]" {
		t.Errorf("HideDestinations = %q", got)
	}
}

func TestLogPanic(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelError)
	alerts := OpenAlerts(dir)
	l.SetAlerts(alerts)
	func() {
		defer func() {
			if value := recover(); value != nil {
				l.LogPanic(value, "runtime", "watch")
			}
		}()
		var nilMap map[string]int
		nilMap["x"] = 1 //nolint:staticcheck // SA5000: the panic is the test
	}()
	l.Close()
	records, _ := Tail(dir, 1)
	if len(records) != 1 || records[0].Level != "fatal" || !records[0].Notify || records[0].Code != "PANIC" ||
		!strings.Contains(records[0].Stack, "TestLogPanic") || !strings.Contains(records[0].Err, "nil map") {
		t.Fatalf("records = %+v", records)
	}
	if list := alerts.List(); len(list) != 1 || list[0].Level != "fatal" || list[0].Target != "runtime" {
		t.Fatalf("alerts = %+v", list)
	}
}
