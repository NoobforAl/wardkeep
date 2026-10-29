// Package logs keeps the server's log in server.log in the data directory
// (rotated at 4 MB, one old file kept), so the CLI, the TUI and the web API
// can show what the running server logged.
//
// Every line is one JSON record (docs/logging.md): time, level, source, msg
// and the optional context keys (target, op, conn, user, code, err, notify,
// caller, stack). Records below the log's level are dropped before anything
// is formatted. Records with notify:true also become alerts (alerts.go).
// Tail and Query still read the plain text lines older servers wrote.
package logs

import (
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/NoobforAl/omnitun/core/buildinfo"
)

const (
	fileName = "server.log"
	// maxSize is when the file is rotated.
	maxSize = 4 << 20
	// SourceServer is the source of the server's own records.
	SourceServer = "server"
	// SourceSingBox is the source of what sing-box logged.
	SourceSingBox = "sing-box"
)

// Level is a record's severity; a log keeps the records at or above its level.
type Level int32

// The levels, lowest first. LevelFatal is a panic or a crash.
const (
	LevelTrace Level = iota
	LevelDebug
	LevelInfo
	LevelWarn
	LevelError
	LevelFatal
)

var levelNames = [...]string{"trace", "debug", "info", "warn", "error", "fatal"}

// String is the level's name in a record.
func (level Level) String() string {
	if level < LevelTrace || level > LevelFatal {
		return "info"
	}
	return levelNames[level]
}

// ParseLevel reads a level name (any case; "warning" and "panic" are accepted too).
func ParseLevel(name string) (Level, bool) {
	switch name { // the exact names first: no allocation on the hot path
	case "trace":
		return LevelTrace, true
	case "debug":
		return LevelDebug, true
	case "info":
		return LevelInfo, true
	case "warn":
		return LevelWarn, true
	case "error":
		return LevelError, true
	case "fatal":
		return LevelFatal, true
	}
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "trace":
		return LevelTrace, true
	case "debug":
		return LevelDebug, true
	case "info":
		return LevelInfo, true
	case "warn", "warning":
		return LevelWarn, true
	case "error", "err":
		return LevelError, true
	case "fatal", "panic", "crit", "critical":
		return LevelFatal, true
	}
	return LevelInfo, false
}

// DefaultLevel is the level a log starts at: error in release builds, debug
// in development builds.
func DefaultLevel() Level {
	if buildinfo.Release() {
		return LevelError
	}
	return LevelDebug
}

// LevelWarning is the help text of every setting that lowers the level.
const LevelWarning = "debug and trace logging slow the server down and keep more detail " +
	"(client IP addresses, user names); turn it back to the default when you are done"

// Record is one log entry. The file stores Extra's keys next to the others;
// readers keep keys they do not know there.
type Record struct {
	Time   time.Time `json:"time" doc:"When it happened (UTC)"`
	Level  string    `json:"level" enum:"trace,debug,info,warn,error,fatal" doc:"fatal is a panic or a crash"`
	Source string    `json:"source" doc:"The part that logged it: server, sing-box, dnstt, ..."`
	Msg    string    `json:"msg" doc:"What happened"`
	Target string    `json:"target,omitempty" doc:"Finer origin: the protocol or inbound (e.g. inbound/trojan[trojan]), api, subscription"`
	Op     string    `json:"op,omitempty" doc:"What was being done: start, reload, acme, ..."`
	Conn   string    `json:"conn,omitempty" doc:"Id of one client connection"`
	User   string    `json:"user,omitempty" doc:"The VPN user's name, where known"`
	Code   string    `json:"code,omitempty" doc:"Stable error code"`
	Err    string    `json:"err,omitempty" doc:"The error chain"`
	Notify bool      `json:"notify,omitempty" doc:"Nothing handled this failure; it is also an alert"`
	Caller string    `json:"caller,omitempty" doc:"file:line where it was logged"`
	Stack  string    `json:"stack,omitempty" doc:"Stack trace of a panic"`
	// Extra holds keys this version does not know (written by a newer one).
	Extra map[string]string `json:"extra,omitempty" doc:"Keys this server version does not know"`
}

// Log is an append-only log file.
type Log struct {
	dir   string
	level atomic.Int32

	mu     sync.Mutex
	f      *os.File
	size   int64
	buf    []byte // the line being written (guarded by mu)
	now    func() time.Time
	mirror io.Writer // also gets every line (the process's stderr while it serves)
	alerts atomic.Pointer[Alerts]
}

// Open prepares the log in dir at DefaultLevel; the file is created on the first write.
func Open(dir string) *Log {
	l := &Log{dir: dir, now: time.Now}
	l.level.Store(int32(DefaultLevel()))
	return l
}

func (l *Log) path() string { return filepath.Join(l.dir, fileName) }

// SetLevel changes the lowest level written, at once.
func (l *Log) SetLevel(level Level) {
	if l != nil {
		l.level.Store(int32(level))
	}
}

// Level is the lowest level written.
func (l *Log) Level() Level {
	if l == nil {
		return LevelFatal
	}
	return Level(l.level.Load())
}

// Enabled reports whether records at level are written. Check it before
// building an expensive message.
func (l *Log) Enabled(level Level) bool {
	return l != nil && int32(level) >= l.level.Load()
}

// SetMirror also writes every line to w (nil stops it).
func (l *Log) SetMirror(w io.Writer) {
	l.mu.Lock()
	l.mirror = w
	l.mu.Unlock()
}

// SetAlerts makes records with notify:true alerts in store (nil stops it).
func (l *Log) SetAlerts(store *Alerts) {
	if l != nil {
		l.alerts.Store(store)
	}
}

func (l *Log) openLocked() error {
	if l.f != nil {
		return nil
	}
	if err := os.MkdirAll(l.dir, 0o700); err != nil {
		return err
	}
	file, err := os.OpenFile(l.path(), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	fi, err := file.Stat()
	if err != nil {
		file.Close()
		return err
	}
	l.f, l.size = file, fi.Size()
	return nil
}

func (l *Log) rotateLocked() {
	l.f.Close()
	l.f = nil
	os.Remove(l.path() + ".1")
	_ = os.Rename(l.path(), l.path()+".1")
}

// Write appends a server record with level (a level name; unknown names are
// info) and message. It is kept for callers that only have text.
func (l *Log) Write(level, message string) {
	parsed, _ := ParseLevel(level)
	if !l.Enabled(parsed) {
		return
	}
	l.Log(parsed, Record{Msg: message})
}

// Log appends rec at level, if the log keeps that level. Time (when zero),
// Level and Source (when empty: server) are filled in; text is cleaned of
// terminal control characters, and line breaks become spaces (except in the
// stack). A record with Notify also becomes an alert.
func (l *Log) Log(level Level, rec Record) {
	if !l.Enabled(level) {
		return
	}
	if rec.Time.IsZero() {
		rec.Time = l.now()
	}
	rec.Level = level.String()
	if rec.Source == "" {
		rec.Source = SourceServer
	}
	l.mu.Lock()
	l.buf = appendRecord(l.buf[:0], &rec)
	if l.openLocked() == nil {
		if l.size+int64(len(l.buf)) > maxSize {
			l.rotateLocked()
		}
		if l.openLocked() == nil {
			n, _ := l.f.Write(l.buf)
			l.size += int64(n)
		}
	}
	if l.mirror != nil {
		_, _ = l.mirror.Write(l.buf)
	}
	if cap(l.buf) > 64<<10 { // a stack trace: do not keep a large buffer for good
		l.buf = nil
	}
	l.mu.Unlock()
	if rec.Notify && level >= LevelError {
		if store := l.alerts.Load(); store != nil {
			store.Add(rec)
		}
	}
}

// Close releases the file.
func (l *Log) Close() {
	if l == nil {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.f != nil {
		l.f.Close()
		l.f = nil
	}
}

// appendRecord writes rec as one JSON line, keys in the contract's order.
func appendRecord(buf []byte, rec *Record) []byte {
	buf = append(buf, `{"time":"`...)
	buf = rec.Time.UTC().AppendFormat(buf, "2006-01-02T15:04:05.000Z07:00")
	buf = append(buf, `","level":"`...)
	buf = append(buf, rec.Level...)
	buf = append(buf, '"')
	buf = appendField(buf, "source", rec.Source)
	buf = appendField(buf, "msg", rec.Msg)
	for _, field := range [...]struct{ key, value string }{
		{"target", rec.Target}, {"op", rec.Op}, {"conn", rec.Conn}, {"user", rec.User},
		{"code", rec.Code}, {"err", rec.Err},
	} {
		if field.value != "" {
			buf = appendField(buf, field.key, field.value)
		}
	}
	if rec.Notify {
		buf = append(buf, `,"notify":true`...)
	}
	if rec.Caller != "" {
		buf = appendField(buf, "caller", rec.Caller)
	}
	if rec.Stack != "" {
		buf = append(buf, `,"stack":`...)
		buf = appendString(buf, cleanLines(rec.Stack))
	}
	for _, key := range sortedKeys(rec.Extra) {
		if !knownKey(key) {
			buf = appendField(buf, clean(key, true), rec.Extra[key])
		}
	}
	return append(buf, "}\n"...)
}

func appendField(buf []byte, key, value string) []byte {
	buf = append(buf, ',', '"')
	buf = append(buf, key...)
	buf = append(buf, '"', ':')
	return appendString(buf, clean(value, true))
}

// appendString writes s as a JSON string.
func appendString(buf []byte, s string) []byte {
	const hex = "0123456789abcdef"
	buf = append(buf, '"')
	start := 0
	for i := 0; i < len(s); {
		c := s[i]
		if c >= 0x20 && c != '"' && c != '\\' && c < utf8.RuneSelf {
			i++
			continue
		}
		if c < utf8.RuneSelf {
			buf = append(buf, s[start:i]...)
			switch c {
			case '"', '\\':
				buf = append(buf, '\\', c)
			case '\n':
				buf = append(buf, '\\', 'n')
			case '\t':
				buf = append(buf, '\\', 't')
			case '\r':
				buf = append(buf, '\\', 'r')
			default:
				buf = append(buf, '\\', 'u', '0', '0', hex[c>>4], hex[c&0xf])
			}
			i++
			start = i
			continue
		}
		r, size := utf8.DecodeRuneInString(s[i:])
		if r == utf8.RuneError && size == 1 {
			buf = append(buf, s[start:i]...)
			buf = append(buf, `�`...)
			i += size
			start = i
			continue
		}
		i += size
	}
	buf = append(buf, s[start:]...)
	return append(buf, '"')
}

var ansi = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)

// plain reports whether s is printable ASCII without leading, trailing or
// doubled spaces: what clean would return unchanged (the common case).
func plain(s string) bool {
	previousSpace := true
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c < 0x20 || c >= 0x7f {
			return false
		}
		if c == ' ' {
			if previousSpace {
				return false
			}
			previousSpace = true
			continue
		}
		previousSpace = false
	}
	return !previousSpace || s == ""
}

// clean makes text safe to print on a terminal: colour codes are removed and
// every control or invisible formatting character (ESC, BEL, backspace, the
// C1 range, bidi overrides, zero-width marks) is dropped, so a user name or a
// request header logged by the server cannot move the cursor, rewrite the
// screen or disguise a line. With collapse, runs of whitespace become one space.
func clean(s string, collapse bool) string {
	if plain(s) {
		return s
	}
	if strings.IndexByte(s, 0x1b) >= 0 {
		s = ansi.ReplaceAllString(s, "")
	}
	var out strings.Builder
	out.Grow(len(s))
	space := false
	for _, r := range s {
		switch {
		case unicode.IsSpace(r) && !collapse:
			if r == ' ' {
				out.WriteByte(' ')
			}
		case unicode.IsSpace(r):
			space = true
		case unicode.IsControl(r) || unicode.Is(unicode.Cf, r):
		default:
			if space && out.Len() > 0 {
				out.WriteByte(' ')
			}
			space = false
			out.WriteRune(r)
		}
	}
	return out.String()
}

// cleanLines cleans every line of a multi-line text (a stack trace) and keeps the line breaks.
func cleanLines(s string) string {
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	for i, line := range lines {
		lines[i] = clean(strings.ReplaceAll(line, "\t", "    "), false)
	}
	return strings.Join(lines, "\n")
}
