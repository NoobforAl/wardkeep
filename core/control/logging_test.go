package control

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/logrec"
)

func TestLoggingGetSet(t *testing.T) {
	t.Cleanup(logrec.ResetLevel)
	s, _ := newTestServer(t, ServerConfig{Grace: -1})
	call := func(method, params string) LoggingSettings {
		t.Helper()
		res, err := s.Call(method, json.RawMessage(params))
		if err != nil {
			t.Fatalf("%s %s: %v", method, params, err)
		}
		return res.(LoggingSettings)
	}

	got := call("logging.get", "")
	if got.Level != "debug" || got.Default != "debug" || got.Mode != "dev" || got.Until != nil {
		t.Fatalf("logging.get = %+v", got)
	}
	until := time.Now().Add(150 * time.Millisecond).UTC().Format(time.RFC3339Nano)
	got = call("logging.set", `{"level":"trace","until":"`+until+`"}`)
	if got.Level != "trace" || got.Until == nil || logrec.Current() != logrec.LevelTrace {
		t.Fatalf("logging.set = %+v", got)
	}
	deadline := time.Now().Add(3 * time.Second)
	for call("logging.get", "").Level != "debug" {
		if time.Now().After(deadline) {
			t.Fatal("the level did not return to the default at until")
		}
		time.Sleep(20 * time.Millisecond)
	}
	if got := call("logging.get", ""); got.Until != nil {
		t.Fatalf("until kept after the revert: %+v", got)
	}

	if got = call("logging.set", `{"level":"error"}`); got.Level != "error" || got.Until != nil {
		t.Fatalf("logging.set error = %+v", got)
	}
	if got = call("logging.set", `{"level":""}`); got.Level != "debug" {
		t.Fatalf("logging.set default = %+v", got)
	}
	for _, params := range []string{`{"level":"loud"}`, `{"level":"info","until":"2001-01-01T00:00:00Z"}`} {
		if _, err := s.Call("logging.set", json.RawMessage(params)); err == nil || !strings.Contains(err.Error(), CodeBadRequest) {
			t.Errorf("logging.set %s: %v", params, err)
		}
	}
}

// A "log" event carries the record, plus its text as "message" for older apps.
func TestLogEntryJSON(t *testing.T) {
	entry := LogEntry{logrec.Record{
		Time: time.Date(2026, 10, 29, 1, 2, 3, 0, time.UTC), Level: logrec.LevelError, Source: logrec.SourceCore,
		Msg: "the Tor client stopped on its own", Conn: "ab12cd", Code: "TOR_EXITED", Notify: true,
	}}
	raw, err := json.Marshal(Event{Event: "log", Data: entry})
	if err != nil {
		t.Fatal(err)
	}
	want := `{"event":"log","data":{"time":"2026-10-29T01:02:03.000Z","level":"error","source":"core",` +
		`"msg":"the Tor client stopped on its own","conn":"ab12cd","code":"TOR_EXITED","notify":true,` +
		`"message":"the Tor client stopped on its own"}}`
	if string(raw) != want {
		t.Fatalf("got  %s\nwant %s", raw, want)
	}
	var back struct {
		Data LogEntry `json:"data"`
	}
	if err := json.Unmarshal(raw, &back); err != nil {
		t.Fatal(err)
	}
	if back.Data.Msg != entry.Msg || back.Data.Extra != nil || !back.Data.Notify {
		t.Fatalf("read back: %+v", back.Data)
	}
}

// Records reach the clients as "log" events and ServerConfig.OnLog.
func TestLogRecordsArePublished(t *testing.T) {
	got := make(chan logrec.Record, 4)
	s, addr := newTestServer(t, ServerConfig{Grace: -1, OnLog: func(rec logrec.Record) { got <- rec }})
	cl, err := Dial(context.Background(), addr, s.Token())
	if err != nil {
		t.Fatal(err)
	}
	defer cl.Close()
	s.logf(logrec.LevelError, "kill switch: cannot remove the block: %v", "dial 192.0.2.1:53")
	select {
	case rec := <-got:
		if rec.Msg != "kill switch: cannot remove the block: dial [addr]" || rec.Source != logrec.SourceCore {
			t.Fatalf("record: %+v", rec)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("OnLog was not called")
	}
	timeout := time.After(5 * time.Second)
	for {
		select {
		case ev := <-cl.Events():
			if ev.Event != "log" {
				continue
			}
			var entry LogEntry
			if err := json.Unmarshal(ev.Data, &entry); err != nil {
				t.Fatal(err)
			}
			if entry.Level != logrec.LevelError || !strings.HasPrefix(entry.Msg, "kill switch") {
				t.Fatalf("event: %+v", entry)
			}
			return
		case <-timeout:
			t.Fatal("no log event")
		}
	}
}
