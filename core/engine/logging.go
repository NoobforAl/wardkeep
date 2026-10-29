package engine

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/sagernet/sing-box/log"

	"github.com/NoobforAl/omnitun/core/logrec"
)

// Codes of failures that only the log reports (with notify), next to the State.ErrorCode values in errors.go.
const (
	ErrTorExited   = "TOR_EXITED"   // the Tor client ended on its own while the tunnel used it
	ErrDNSTTExited = "DNSTT_EXITED" // the DNS tunnel ended on its own while the tunnel used it
	ErrEngineFatal = "ENGINE_FATAL" // sing-box reported a fatal error
	// ErrTorStreamFailed is omnitun-tor's code for one stream that could not be opened (logged at warn).
	ErrTorStreamFailed = "TOR_STREAM_FAILED"
	ErrPanic           = logrec.CodePanic
)

// attempt is one connect attempt: every record it logs carries its conn id and the profile it was started for.
type attempt struct {
	conn    string
	profile string
}

// newConnID is a short random id for one connect attempt.
func newConnID() string {
	var raw [3]byte
	rand.Read(raw[:])
	return hex.EncodeToString(raw[:])
}

// beginAttemptLocked starts a new connect attempt for the profile id (or "auto"). e.mu must be held.
func (e *Engine) beginAttemptLocked(profileID string) {
	e.attempt.Store(&attempt{conn: newConnID(), profile: profileID})
}

// logFields are a record's optional context; the attempt's conn and profile are added on their own.
type logFields struct {
	source  string
	target  string
	op      string
	profile string
	code    string
	err     error
	notify  bool
	// detached keeps the record out of the current connect attempt (a latency test runs beside it).
	detached bool
}

// logf logs a core record at the named level. The message is formatted only when the level is on.
func (e *Engine) logf(level, format string, args ...any) {
	parsed, _ := logrec.ParseLevel(level)
	if !logrec.Enabled(parsed) {
		return
	}
	e.emit(parsed, logFields{}, 1, format, args...)
}

// logWith logs a record with context fields. A notify record is never gated: the user has to hear of it.
func (e *Engine) logWith(level logrec.Level, fields logFields, format string, args ...any) {
	if !logrec.Enabled(level) && !fields.notify {
		return
	}
	e.emit(level, fields, 1, format, args...)
}

// emit builds and delivers a record; skip is the number of frames between the logging call site and emit's caller.
func (e *Engine) emit(level logrec.Level, fields logFields, skip int, format string, args ...any) {
	if e.cfg.OnLog == nil {
		return
	}
	rec := logrec.Record{
		Time:    time.Now(),
		Level:   level,
		Source:  fields.source,
		Target:  fields.target,
		Op:      fields.op,
		Profile: fields.profile,
		Code:    fields.code,
		Notify:  fields.notify,
		Msg:     fmt.Sprintf(format, args...),
	}
	if fields.err != nil {
		rec.Err = fields.err.Error()
	}
	if logrec.WantCaller() {
		rec.Caller = logrec.Caller(skip + 1)
	}
	e.deliver(rec, fields.detached)
}

// deliver scrubs a record, adds the connect attempt's context, de-duplicates its notify and hands it on.
func (e *Engine) deliver(rec logrec.Record, detached bool) {
	if e.cfg.OnLog == nil {
		return
	}
	if rec.Source == "" {
		rec.Source = logrec.SourceCore
	}
	rec.Msg, rec.Err = logrec.Scrub(rec.Msg), logrec.Scrub(rec.Err)
	for key, value := range rec.Extra {
		if text, ok := value.(string); ok {
			rec.Extra[key] = logrec.Scrub(text)
		}
	}
	if current := e.attempt.Load(); current != nil && !detached {
		if rec.Conn == "" {
			rec.Conn = current.conn
		}
		if rec.Profile == "" {
			rec.Profile = current.profile
		}
		if rec.Op == "" {
			rec.Op = "connect"
		}
	}
	if rec.Notify && rec.Level < logrec.LevelError {
		rec.Level = logrec.LevelError
	}
	logrec.Dedupe(&rec)
	e.cfg.OnLog(rec)
}

// onPanic reports a panic recovered in one of the engine's goroutines (see recoverLoop).
func (e *Engine) onPanic(rec logrec.Record) { e.deliver(rec, false) }

// recoverLoop, deferred at the top of a long-running engine goroutine, logs a panic as a fatal record with its
// stack and notify, and ends the connection in the error state instead of the process.
func (e *Engine) recoverLoop(op string) {
	value := recover()
	if value == nil {
		return
	}
	rec := logrec.PanicRecord(logrec.SourceCore, op, value)
	e.onPanic(rec)
	if logrec.Repanic {
		panic(value) // tests: a bug fails the test
	}
	// The goroutine's own deferred unlocks have run by now; a lock it took without one stays taken, and then
	// waiting for it here only parks this goroutine, which is ending anyway.
	e.mu.Lock()
	if e.state.Status == StatusRunning || e.state.Status == StatusStarting {
		_ = e.teardownLocked()
		e.dropReported = true
		e.setState(State{Status: StatusError, Error: "Internal error: " + rec.Msg, Selected: e.state.Selected})
		e.dropReported = false
	}
	e.mu.Unlock()
}

// notifyDropLocked logs a running connection that fell to the error state; nothing else tells the user of it.
// setState calls it. e.mu must be held.
func (e *Engine) notifyDropLocked(prev Status, state State) {
	if prev != StatusRunning || state.Status != StatusError || e.dropReported {
		return
	}
	e.logWith(logrec.LevelError, logFields{code: state.ErrorCode, notify: true}, "the connection failed: %s", state.Error)
}

// singboxLevel is the record level of a sing-box log level.
func singboxLevel(level log.Level) logrec.Level {
	switch level {
	case log.LevelPanic, log.LevelFatal:
		return logrec.LevelFatal
	case log.LevelError:
		return logrec.LevelError
	case log.LevelWarn:
		return logrec.LevelWarn
	case log.LevelInfo:
		return logrec.LevelInfo
	case log.LevelDebug:
		return logrec.LevelDebug
	}
	return logrec.LevelTrace
}

// singboxLogLevel is the level sing-box is started with: the effective level (sing-box has the same names).
func singboxLogLevel() string { return logrec.Current().String() }

// torLogLevel is the --log-level omnitun-tor is started with (it takes the same names).
func torLogLevel() string { return logrec.Current().String() }

// singboxPrefix is what sing-box puts before a line it hands the platform writer: the level label with seconds
// since start ("ERROR[0012] "), then a connection's id and age ("[3021 54ms] ") when it is about one.
var singboxPrefix = regexp.MustCompile(`^[A-Z]+\[\d+\] (\[\d+ [^\]]*\] )?`)

// splitSingboxLine takes sing-box's prefix off a line and its "outbound/vless[p_19]: " tag, for the record's target.
func splitSingboxLine(message string) (target, rest string) {
	message = strings.TrimSpace(singboxPrefix.ReplaceAllString(message, ""))
	tag, text, ok := strings.Cut(message, ": ")
	if !ok || strings.ContainsAny(tag, " \t") || !strings.Contains(tag, "/") {
		return "", message
	}
	return tag, text
}
