package logrec

import (
	"fmt"
	"io"
	"sync"
	"time"
)

// Logger writes records as JSON lines (a process's own stdout, stderr or log file).
type Logger struct {
	mu     sync.Mutex
	out    io.Writer
	source string
}

// NewLogger writes records to out; records without a source get source.
func NewLogger(out io.Writer, source string) *Logger {
	return &Logger{out: out, source: source}
}

// Logf writes a record at level when the gate keeps it; the message is formatted only then.
func (l *Logger) Logf(level Level, format string, args ...any) {
	if !Enabled(level) {
		return
	}
	rec := Record{Time: time.Now(), Level: level, Msg: Scrub(fmt.Sprintf(format, args...))}
	if WantCaller() {
		rec.Caller = Caller(1)
	}
	l.Emit(rec)
}

// Printf logs at info level (for code that takes a printf-style function).
func (l *Logger) Printf(format string, args ...any) {
	if !Enabled(LevelInfo) {
		return
	}
	rec := Record{Time: time.Now(), Level: LevelInfo, Msg: Scrub(fmt.Sprintf(format, args...))}
	if WantCaller() {
		rec.Caller = Caller(1)
	}
	l.Emit(rec)
}

// Errorf logs at error level.
func (l *Logger) Errorf(format string, args ...any) {
	if !Enabled(LevelError) {
		return
	}
	rec := Record{Time: time.Now(), Level: LevelError, Msg: Scrub(fmt.Sprintf(format, args...))}
	if WantCaller() {
		rec.Caller = Caller(1)
	}
	l.Emit(rec)
}

// Emit writes a finished record (fatal ones always; others when the gate keeps them).
func (l *Logger) Emit(rec Record) {
	if l == nil || l.out == nil || (rec.Level < LevelFatal && !Enabled(rec.Level)) {
		return
	}
	if rec.Source == "" {
		rec.Source = l.source
	}
	if rec.Time.IsZero() {
		rec.Time = time.Now()
	}
	line, _ := rec.MarshalJSON()
	line = append(line, '\n')
	l.mu.Lock()
	defer l.mu.Unlock()
	_, _ = l.out.Write(line)
}
