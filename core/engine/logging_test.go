package engine

import (
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sagernet/sing-box/log"

	"github.com/NoobforAl/omnitun/core/logrec"
)

// recordSink collects an engine's log records.
type recordSink struct {
	mu      sync.Mutex
	records []logrec.Record
}

func (s *recordSink) add(rec logrec.Record) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.records = append(s.records, rec)
}

func (s *recordSink) take() []logrec.Record {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := s.records
	s.records = nil
	return out
}

func notifying(records []logrec.Record) []logrec.Record {
	var out []logrec.Record
	for _, rec := range records {
		if rec.Notify {
			out = append(out, rec)
		}
	}
	return out
}

// A running connection that falls to the error state tells the user once per attempt and code; a connection that
// fails while connecting does not (the app shows that failure itself).
func TestNotifyWhenRunningConnectionFails(t *testing.T) {
	sink := &recordSink{}
	e := New(Config{DataDir: tempDir(t), OnLog: sink.add})
	failed := State{Status: StatusError, Error: stageLabel[StageHandshake] + " failed: the server did not answer in time"}

	e.mu.Lock()
	e.beginAttemptLocked("p_1")
	e.setState(State{Status: StatusStarting})
	e.setState(failed)
	e.mu.Unlock()
	if got := notifying(sink.take()); len(got) != 0 {
		t.Fatalf("a failed connect notified: %+v", got)
	}

	e.mu.Lock()
	e.setState(State{Status: StatusRunning})
	e.setState(failed)
	e.setState(State{Status: StatusRunning})
	e.setState(failed)
	e.mu.Unlock()
	got := notifying(sink.take())
	if len(got) != 1 {
		t.Fatalf("notify records: %+v", got)
	}
	conn := got[0].Conn
	if got[0].Level != logrec.LevelError || got[0].Code != ErrTimeout || conn == "" || got[0].Profile != "p_1" || got[0].Op != "connect" {
		t.Fatalf("notify record: %+v", got[0])
	}

	// The next attempt has its own conn and may tell the user again.
	e.mu.Lock()
	e.beginAttemptLocked("p_1")
	e.setState(State{Status: StatusRunning})
	e.setState(failed)
	e.mu.Unlock()
	got = notifying(sink.take())
	if len(got) != 1 || got[0].Conn == conn {
		t.Fatalf("next attempt: %+v", got)
	}
}

// A panic in an engine goroutine becomes a fatal record (stack, notify) and an error state, not a crash.
func TestEngineGoroutinePanicIsRecovered(t *testing.T) {
	logrec.Repanic = false
	t.Cleanup(func() { logrec.Repanic = true })
	sink := &recordSink{}
	e := New(Config{DataDir: tempDir(t), OnLog: sink.add})
	e.mu.Lock()
	e.beginAttemptLocked("p_2")
	e.setState(State{Status: StatusRunning, Selected: "p_2"})
	e.mu.Unlock()

	done := make(chan struct{})
	go func() {
		defer close(done)
		defer e.recoverLoop("connect")
		e.mu.Lock()
		defer e.mu.Unlock()
		panic("boom")
	}()
	<-done
	if st := e.State(); st.Status != StatusError || !strings.Contains(st.Error, "boom") {
		t.Fatalf("state after the panic: %+v", st)
	}
	got := notifying(sink.take())
	if len(got) != 1 {
		t.Fatalf("notify records: %+v", got)
	}
	if rec := got[0]; rec.Level != logrec.LevelFatal || rec.Code != ErrPanic || rec.Stack == "" || rec.Conn == "" || rec.Profile != "p_2" {
		t.Fatalf("panic record: %+v", rec)
	}
}

// sing-box lines become records of their own source and level, scrubbed, gated, and a fatal one notifies.
func TestSingboxLines(t *testing.T) {
	t.Cleanup(logrec.ResetLevel)
	logrec.SetLevel(logrec.LevelError, time.Time{})
	sink := &recordSink{}
	e := New(Config{DataDir: tempDir(t), OnLog: sink.add})
	writer := logWriter{e}
	writer.WriteMessage(log.LevelDebug, "DEBUG[0003] [1234 5ms] outbound/vless[p_1]: dial example.com:443")
	if got := sink.take(); len(got) != 0 {
		t.Fatalf("a debug line passed the error level: %+v", got)
	}
	writer.WriteMessage(log.LevelFatal, "\x1b[31mFATAL\x1b[0m[0003] outbound/vless[p_1]: dial tcp 192.0.2.1:443: refused")
	got := sink.take()
	if len(got) != 1 {
		t.Fatalf("records: %+v", got)
	}
	rec := got[0]
	if rec.Source != logrec.SourceSingBox || rec.Level != logrec.LevelFatal || rec.Target != "outbound/vless[p_1]" ||
		rec.Msg != "dial tcp [addr]: refused" || !rec.Notify || rec.Code != ErrEngineFatal {
		t.Fatalf("record: %+v", rec)
	}
}

// The level gate is checked before a message is formatted, and debug records carry their caller.
func TestEngineLevelGate(t *testing.T) {
	t.Cleanup(logrec.ResetLevel)
	sink := &recordSink{}
	e := New(Config{DataDir: tempDir(t), OnLog: sink.add})
	logrec.SetLevel(logrec.LevelError, time.Time{})
	e.logf("info", "starting %d profile(s)", 2)
	if got := sink.take(); len(got) != 0 {
		t.Fatalf("an info record passed the error level: %+v", got)
	}
	logrec.SetLevel(logrec.LevelDebug, time.Time{})
	e.logf("info", "starting %d profile(s)", 2)
	got := sink.take()
	if len(got) != 1 || got[0].Msg != "starting 2 profile(s)" || !strings.HasPrefix(got[0].Caller, "engine/logging_test.go:") || got[0].Source != logrec.SourceCore {
		t.Fatalf("records: %+v", got)
	}
}
