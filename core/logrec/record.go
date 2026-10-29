// Package logrec is the core's log record (docs/logging.md): one JSON object per
// line with slog-style keys, the level gate every layer checks before it formats
// a message, the notify de-duplication and the panic report.
package logrec

import (
	"bytes"
	"encoding/json"
	"fmt"
	"maps"
	"slices"
	"strings"
	"time"
)

// Level orders records from the most detailed (trace) to the most severe (fatal).
type Level int8

const (
	LevelTrace Level = iota
	LevelDebug
	LevelInfo
	LevelWarn
	LevelError
	// LevelFatal is a panic or the crash of a process.
	LevelFatal
)

var levelNames = [...]string{"trace", "debug", "info", "warn", "error", "fatal"}

func (l Level) String() string {
	if l < LevelTrace || l > LevelFatal {
		return "info"
	}
	return levelNames[l]
}

// ParseLevel reads a level name; ok is false for a name that is not one. It also
// takes the spellings other loggers use ("warning", "panic", "critical").
func ParseLevel(name string) (level Level, ok bool) {
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
	case "fatal", "panic", "critical", "crit":
		return LevelFatal, true
	}
	return LevelInfo, false
}

// Sources: the part of Wardkeep that logged a record.
const (
	SourceCore     = "core"
	SourceSingBox  = "sing-box"
	SourceTor      = "tor"
	SourceDNSTT    = "dnstt"
	SourceDNSCrypt = "dnscrypt"
	SourceServer   = "server"
	SourceApp      = "app"
)

// Record is one log record. The JSON keys are the contract's (docs/logging.md §1); Extra holds any other keys
// (another process's own fields) and is written flattened next to them.
type Record struct {
	Time   time.Time
	Level  Level
	Source string
	Msg    string
	// Target is a finer origin: a Rust module, a sing-box tag.
	Target string
	// Op is what was being done: connect, bootstrap, import, subscription, test, ...
	Op string
	// Conn is the short random id of one connect attempt.
	Conn string
	// Profile is the profile's id, never its name or address.
	Profile string
	// Code is a stable error code (the engine's ErrorCode values).
	Code string
	// Err is the (scrubbed) error chain.
	Err string
	// Notify: nothing handled this failure and the user should be told.
	Notify bool
	// Caller is file:line; set at debug level and for panics.
	Caller string
	// Stack is a panic's stack trace.
	Stack string
	// User is the VPN user's name (the server only).
	User  string
	Extra map[string]any
}

// timeLayout is RFC 3339 in UTC with milliseconds.
const timeLayout = "2006-01-02T15:04:05.000Z07:00"

// knownKeys are the contract's keys; an Extra key with one of these names is not written.
var knownKeys = map[string]bool{
	"time": true, "level": true, "source": true, "msg": true, "target": true, "op": true, "conn": true,
	"profile": true, "code": true, "err": true, "notify": true, "caller": true, "stack": true, "user": true,
}

// MarshalJSON writes the record with its keys in the contract's order, then the extra keys sorted.
func (r Record) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString(`{"time":`)
	writeString(&buf, r.Time.UTC().Format(timeLayout))
	buf.WriteString(`,"level":`)
	writeString(&buf, r.Level.String())
	writeField(&buf, "source", r.Source, true)
	writeField(&buf, "msg", r.Msg, true)
	writeField(&buf, "target", r.Target, false)
	writeField(&buf, "op", r.Op, false)
	writeField(&buf, "conn", r.Conn, false)
	writeField(&buf, "profile", r.Profile, false)
	writeField(&buf, "code", r.Code, false)
	writeField(&buf, "err", r.Err, false)
	if r.Notify {
		buf.WriteString(`,"notify":true`)
	}
	writeField(&buf, "caller", r.Caller, false)
	writeField(&buf, "stack", r.Stack, false)
	writeField(&buf, "user", r.User, false)
	for _, key := range slices.Sorted(maps.Keys(r.Extra)) {
		if knownKeys[key] {
			continue
		}
		value, err := json.Marshal(r.Extra[key])
		if err != nil {
			value, _ = json.Marshal(fmt.Sprint(r.Extra[key]))
		}
		buf.WriteByte(',')
		writeString(&buf, key)
		buf.WriteByte(':')
		buf.Write(value)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

func writeField(buf *bytes.Buffer, key, value string, always bool) {
	if value == "" && !always {
		return
	}
	buf.WriteByte(',')
	writeString(buf, key)
	buf.WriteByte(':')
	writeString(buf, value)
}

func writeString(buf *bytes.Buffer, value string) {
	encoded, _ := json.Marshal(value)
	buf.Write(encoded)
}

// UnmarshalJSON reads a record; keys outside the contract go to Extra. A missing or unknown level is info.
func (r *Record) UnmarshalJSON(data []byte) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return err
	}
	*r = Record{}
	text := func(key string) string {
		raw, ok := fields[key]
		if !ok {
			return ""
		}
		delete(fields, key)
		var value string
		if json.Unmarshal(raw, &value) != nil {
			return strings.Trim(string(raw), `"`)
		}
		return value
	}
	if stamp := text("time"); stamp != "" {
		if parsed, err := time.Parse(time.RFC3339Nano, stamp); err == nil {
			r.Time = parsed
		}
	}
	r.Level, _ = ParseLevel(text("level"))
	r.Source, r.Msg, r.Target, r.Op = text("source"), text("msg"), text("target"), text("op")
	r.Conn, r.Profile, r.Code, r.Err = text("conn"), text("profile"), text("code"), text("err")
	r.Caller, r.Stack, r.User = text("caller"), text("stack"), text("user")
	if raw, ok := fields["notify"]; ok {
		delete(fields, "notify")
		_ = json.Unmarshal(raw, &r.Notify) // not a bool: no notification
	}
	if len(fields) > 0 {
		r.Extra = make(map[string]any, len(fields))
		for key, raw := range fields {
			var value any
			if json.Unmarshal(raw, &value) == nil {
				r.Extra[key] = value
			}
		}
	}
	return nil
}
