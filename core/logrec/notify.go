package logrec

import (
	"fmt"
	"runtime"
	"runtime/debug"
	"strings"
	"sync"
	"testing"
	"time"
)

// CodePanic is the code of a panic's record.
const CodePanic = "PANIC"

// maxNotified bounds the remembered conn+code pairs; past it the memory starts over.
const maxNotified = 1024

var (
	notifiedMu sync.Mutex
	notified   = map[string]struct{}{}
)

// Dedupe clears rec.Notify when a record with the same conn and code already notified, so the user is told once
// about one failure of one connect attempt. Records without a conn are not grouped.
func Dedupe(rec *Record) {
	if !rec.Notify || rec.Conn == "" {
		return
	}
	key := rec.Conn + "\x00" + rec.Code
	notifiedMu.Lock()
	defer notifiedMu.Unlock()
	if _, seen := notified[key]; seen {
		rec.Notify = false
		return
	}
	if len(notified) >= maxNotified {
		clear(notified)
	}
	notified[key] = struct{}{}
}

// Repanic makes Recover panic again once it has reported the panic. It is on in tests, so a bug in a goroutine
// still fails the test instead of turning into a log line; a test of the recover path turns it off.
var Repanic = testing.Testing()

// Recover, deferred at the top of a long-running goroutine, turns a panic into a fatal record (with the stack and
// notify) handed to report, and lets the goroutine end instead of the process. report runs before the goroutine's
// other deferred calls are done, so it must not wait for locks the goroutine may still hold.
func Recover(source, op string, report func(Record)) {
	value := recover()
	if value == nil {
		return
	}
	rec := PanicRecord(source, op, value)
	if report != nil {
		report(rec)
	}
	if Repanic {
		panic(value)
	}
}

// PanicRecord is the fatal record of a recovered panic. Call it from the deferred function that recovered it.
func PanicRecord(source, op string, value any) Record {
	return Record{
		Time:   time.Now(),
		Level:  LevelFatal,
		Source: source,
		Op:     op,
		Msg:    Scrub(fmt.Sprintf("panic: %v", value)),
		Code:   CodePanic,
		Notify: true,
		Caller: panicSite(),
		Stack:  string(debug.Stack()),
	}
}

// panicSite is the file:line that panicked: the frame right after runtime.gopanic.
func panicSite() string {
	pcs := make([]uintptr, 64)
	frames := runtime.CallersFrames(pcs[:runtime.Callers(1, pcs)])
	afterPanic := false
	for {
		frame, more := frames.Next()
		if afterPanic && !strings.HasPrefix(frame.Function, "runtime.") {
			return shortFile(frame.File) + ":" + fmt.Sprint(frame.Line)
		}
		if frame.Function == "runtime.gopanic" {
			afterPanic = true
		}
		if !more {
			return ""
		}
	}
}
