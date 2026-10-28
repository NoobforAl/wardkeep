package control

import (
	"fmt"
	"maps"
	"time"

	"github.com/NoobforAl/omnitun/core/buildinfo"
	"github.com/NoobforAl/omnitun/core/logrec"
)

// LogEntry is pushed as a "log" event: one record of docs/logging.md (keys time, level, source, msg, and the
// optional target, op, conn, profile, code, err, notify, caller, stack, plus any extra keys).
type LogEntry struct {
	logrec.Record
}

// MarshalJSON writes the record and, next to "msg", the same text as "message": the key apps before the
// structured log (0.2.x) read. Drop "message" one release after the app reads "msg".
func (l LogEntry) MarshalJSON() ([]byte, error) {
	rec := l.Record
	rec.Extra = maps.Clone(rec.Extra)
	if rec.Extra == nil {
		rec.Extra = map[string]any{}
	}
	rec.Extra["message"] = rec.Msg
	return rec.MarshalJSON()
}

// UnmarshalJSON reads a record (the "message" twin is dropped).
func (l *LogEntry) UnmarshalJSON(data []byte) error {
	if err := l.Record.UnmarshalJSON(data); err != nil {
		return err
	}
	delete(l.Record.Extra, "message")
	if len(l.Record.Extra) == 0 {
		l.Record.Extra = nil
	}
	return nil
}

// LoggingSettings is the result of logging.get and logging.set.
type LoggingSettings struct {
	// Level is the effective level: trace, debug, info, warn, error or fatal.
	Level string `json:"level"`
	// Default is the level of this build when nobody changed it (error in a release, debug in a dev build).
	Default string `json:"default"`
	// Mode is the build mode: "release" or "dev".
	Mode string `json:"mode"`
	// Until is when a changed level returns to the default; absent when it does not (or nothing was changed).
	Until *time.Time `json:"until,omitempty"`
}

// LoggingParams changes the level: Level "" returns to the default; Until (RFC 3339, optional, in the future)
// returns to the default then. sing-box and Tor take a new level at their next start.
type LoggingParams struct {
	Level string    `json:"level"`
	Until time.Time `json:"until,omitzero"`
}

func loggingSettings() LoggingSettings {
	level, until, _ := logrec.Get()
	out := LoggingSettings{Level: level.String(), Default: logrec.DefaultLevel().String(), Mode: buildinfo.Mode}
	if !until.IsZero() {
		out.Until = &until
	}
	return out
}

func setLogging(params LoggingParams) (LoggingSettings, error) {
	if params.Level == "" {
		logrec.ResetLevel()
		return loggingSettings(), nil
	}
	level, ok := logrec.ParseLevel(params.Level)
	if !ok {
		return LoggingSettings{}, &Error{Code: CodeBadRequest, Message: fmt.Sprintf("unknown log level %q", params.Level)}
	}
	if !params.Until.IsZero() && !params.Until.After(time.Now()) {
		return LoggingSettings{}, &Error{Code: CodeBadRequest, Message: "until is in the past"}
	}
	logrec.SetLevel(level, params.Until)
	return loggingSettings(), nil
}

// logf logs one of the server's own records; the message is formatted only when the level is on.
func (s *Server) logf(level logrec.Level, format string, args ...any) {
	if !logrec.Enabled(level) {
		return
	}
	rec := logrec.Record{Time: time.Now(), Level: level, Source: logrec.SourceCore, Msg: logrec.Scrub(fmt.Sprintf(format, args...))}
	if logrec.WantCaller() {
		rec.Caller = logrec.Caller(1)
	}
	s.publishLog(rec)
}

// publishLog pushes a record to the clients and hands it to ServerConfig.OnLog.
func (s *Server) publishLog(rec logrec.Record) {
	s.broadcast(Event{Event: "log", Data: LogEntry{rec}})
	if s.cfg.OnLog != nil {
		s.cfg.OnLog(rec)
	}
	if s.cfg.Logf != nil && rec.Source == logrec.SourceCore && rec.Conn == "" {
		s.cfg.Logf("%s", rec.Msg)
	}
}

// recoverGoroutine, deferred at the top of a server goroutine, logs a panic as a fatal record (stack, notify)
// and lets the goroutine end instead of the process.
func (s *Server) recoverGoroutine(op string) {
	value := recover()
	if value == nil {
		return
	}
	rec := logrec.PanicRecord(logrec.SourceCore, op, value)
	s.publishLog(rec)
	if logrec.Repanic {
		panic(value)
	}
}
