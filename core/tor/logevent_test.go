package tor

import (
	"testing"

	"github.com/NoobforAl/omnitun/core/logrec"
)

// omnitun-tor's "log" events become records with their own level, and the keys outside the contract stay.
func TestParseLogEvent(t *testing.T) {
	line := `{"event":"log","time":"2026-10-29T01:02:03.456Z","level":"warn","source":"tor","target":"tor_guardmgr",` +
		`"msg":"guard unusable","op":"connect","code":"TOR_STREAM_FAILED","kind":"timeout","max":3,"caller":"guard.rs:10"}`
	rec, ok := parseLogEvent([]byte(line))
	if !ok {
		t.Fatal("not parsed")
	}
	if rec.Level != logrec.LevelWarn || rec.Source != logrec.SourceTor || rec.Target != "tor_guardmgr" || rec.Msg != "guard unusable" ||
		rec.Op != "connect" || rec.Code != "TOR_STREAM_FAILED" || rec.Caller != "guard.rs:10" || rec.Time.IsZero() {
		t.Fatalf("record: %+v", rec)
	}
	if _, has := rec.Extra["event"]; has {
		t.Fatal("the event key was kept")
	}
	if rec.Extra["kind"] != "timeout" || rec.Extra["max"] != 3.0 {
		t.Fatalf("extra keys: %v", rec.Extra)
	}

	fatal, ok := parseLogEvent([]byte(`{"event":"log","level":"fatal","msg":"panicked","notify":true,"stack":"main.rs"}`))
	if !ok || fatal.Level != logrec.LevelFatal || !fatal.Notify || fatal.Stack != "main.rs" || fatal.Source != logrec.SourceTor || fatal.Time.IsZero() {
		t.Fatalf("fatal record: %+v", fatal)
	}
	if _, ok := parseLogEvent([]byte(`not json`)); ok {
		t.Fatal("a broken line parsed")
	}
}

// Anything on stderr is unexpected: an error of the Tor source.
func TestStderrRecord(t *testing.T) {
	rec := stderrRecord("thread 'main' panicked  ")
	if rec.Level != logrec.LevelError || rec.Source != logrec.SourceTor || rec.Msg != "thread 'main' panicked" {
		t.Fatalf("record: %+v", rec)
	}
}
