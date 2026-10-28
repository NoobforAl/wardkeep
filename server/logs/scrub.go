package logs

import (
	"fmt"
	"regexp"
	"runtime/debug"
	"strings"
)

var (
	// addressPattern finds IPv4 and IPv6 addresses (with a port or a zone) and host:port.
	addressPattern = regexp.MustCompile(`\[[0-9a-fA-F:.%a-zA-Z0-9]*:[0-9a-fA-F:.%]*\](:\d+)?` + // [v6]:port
		`|\b\d{1,3}(\.\d{1,3}){3}(:\d+)?\b` + // v4[:port]
		`|\b[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){2,7}(%\w+)?` + // bare v6
		`|\b([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}:\d+\b`) // host:port
	// destinationPattern finds where a connection went in sing-box's messages.
	destinationPattern = regexp.MustCompile(`((?:packet )?connection to )\S+`)
)

// Scrub replaces IP addresses and host:port pairs in text with "[address]",
// for messages from libraries that may name a client or a destination.
func Scrub(text string) string {
	if !strings.ContainsAny(text, ".:") {
		return text
	}
	return addressPattern.ReplaceAllStringFunc(text, func(match string) string {
		if strings.Count(match, ":") == 2 && !strings.ContainsAny(match, "[.") && len(match) <= 8 {
			return match // a clock time such as 12:30:45
		}
		return "[address]"
	})
}

// HideDestinations replaces the destination of "connection to …" in a message.
func HideDestinations(text string) string {
	if !strings.Contains(text, "connection to ") {
		return text
	}
	return destinationPattern.ReplaceAllString(text, "${1}[destination]")
}

// LogPanic writes a recovered panic as a fatal record with the stack and
// notify:true (so it becomes an alert). Call it from a deferred function:
//
//	defer func() {
//		if value := recover(); value != nil {
//			log.LogPanic(value, "runtime", "watch")
//		}
//	}()
func (l *Log) LogPanic(value any, target, op string) {
	l.Log(LevelFatal, Record{
		Target: target, Op: op, Code: "PANIC", Notify: true,
		Msg:   "panic: " + target + " stopped",
		Err:   Scrub(fmt.Sprint(value)),
		Stack: string(debug.Stack()),
	})
}
