package logs

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"
	"unicode/utf8"
)

// Filter selects records for Query.
type Filter struct {
	// Level is the lowest level returned.
	Level Level
	// Since, when set, drops records older than it.
	Since time.Time
	// Limit is how many of the newest matching records are returned.
	Limit int
}

// Tail returns the last count records of the log in dir (oldest first),
// reading the rotated file too when the current one is short. A missing log
// is empty.
func Tail(dir string, count int) ([]Record, error) {
	return Query(dir, Filter{Level: LevelTrace, Limit: count})
}

// Query returns the newest f.Limit records of the log in dir that match f
// (oldest first). The files are read from their end, so the cost is that of
// the records asked for, not of a log that rotates at several MB.
func Query(dir string, f Filter) ([]Record, error) {
	if f.Limit <= 0 {
		return []Record{}, nil
	}
	records := []Record{} // newest first while collecting
	done := false
	for _, name := range []string{fileName, fileName + ".1"} { // newest first
		err := scanBackward(filepath.Join(dir, name), func(line []byte) bool {
			if f.Level > LevelTrace && peekLevel(line) < f.Level {
				return true
			}
			if !f.Since.IsZero() {
				if at := peekTime(line); !at.IsZero() && at.Before(f.Since) {
					done = true // the log is in time order: everything before this is older
					return false
				}
			}
			records = append(records, parseLine(line))
			if len(records) >= f.Limit {
				done = true
				return false
			}
			return true
		})
		if err != nil && !os.IsNotExist(err) {
			return nil, err
		}
		if done {
			break
		}
	}
	slices.Reverse(records)
	return records, nil
}

// scanBackward calls visit with every non-empty line of the file, newest
// first, until visit returns false. The line is only valid during the call.
func scanBackward(path string, visit func(line []byte) bool) error {
	file, err := os.Open(path) //nolint:gosec // G304: log files inside the server's own log folder
	if err != nil {
		return err
	}
	defer file.Close()
	fi, err := file.Stat()
	if err != nil {
		return err
	}
	var (
		pending []byte // the start of the file part already read: a line whose beginning is further back
		pos     = fi.Size()
		chunk   = int64(32 << 10)
	)
	for pos > 0 {
		step := min(chunk, pos)
		pos -= step
		data := make([]byte, step+int64(len(pending)))
		if _, err := file.ReadAt(data[:step], pos); err != nil && err != io.EOF {
			return err
		}
		copy(data[step:], pending)
		for {
			cut := bytes.LastIndexByte(data, '\n')
			if cut < 0 {
				break
			}
			if line := trimLine(data[cut+1:]); len(line) > 0 && !visit(line) {
				return nil
			}
			data = data[:cut]
		}
		pending = data
		chunk = min(chunk*2, 1<<20)
	}
	if line := trimLine(pending); len(line) > 0 {
		visit(line)
	}
	return nil
}

func trimLine(line []byte) []byte {
	return bytes.TrimRight(line, "\r")
}

// peekLevel reads a line's level without parsing all of it (and without allocating).
func peekLevel(line []byte) Level {
	if len(line) == 0 || line[0] != '{' {
		level, _ := ParseLevel(parseText(string(line)).Level)
		return level
	}
	value, ok := peekValue(line, `"level":"`)
	if !ok {
		return LevelInfo
	}
	for level, name := range levelNames {
		if string(value) == name {
			return Level(level)
		}
	}
	level, _ := ParseLevel(string(value))
	return level
}

// peekTime reads a line's time without parsing all of it.
func peekTime(line []byte) time.Time {
	if len(line) == 0 || line[0] != '{' {
		return parseText(string(line)).Time
	}
	var at time.Time
	if value, ok := peekValue(line, `"time":"`); ok {
		at, _ = time.Parse(time.RFC3339Nano, string(value))
	}
	return at
}

// peekValue finds key (with its opening quote) and returns the text up to the
// next quote. It is a shortcut for the lines this package writes; parseLine is
// the exact reader.
func peekValue(line []byte, key string) ([]byte, bool) {
	at := bytes.Index(line, []byte(key))
	if at < 0 {
		return nil, false
	}
	rest := line[at+len(key):]
	before, _, ok := bytes.Cut(rest, []byte{'"'})
	if !ok {
		return nil, false
	}
	return before, true
}

// parseLine reads one line: a JSON record, or a text line an older server
// wrote. Text is cleaned for the terminal either way.
func parseLine(line []byte) Record {
	if len(line) > 0 && line[0] == '{' {
		if rec, ok := parseJSON(line); ok {
			return rec
		}
	}
	return parseText(clean(string(line), false))
}

// parseText reads "2026-10-16 18:00:00 LEVEL message" (and "… SING-BOX WARN
// message" for what sing-box logged), the format before the JSON records. A
// line that is not in it becomes the message of an info record.
func parseText(line string) Record {
	rec := Record{Level: "info", Source: SourceServer, Msg: line}
	const stamp = "2006-01-02 15:04:05"
	if len(line) < len(stamp)+1 || line[len(stamp)] != ' ' {
		return rec
	}
	at, err := time.ParseInLocation(stamp, line[:len(stamp)], time.Local)
	if err != nil {
		return rec
	}
	rec.Time = at
	rest := line[len(stamp)+1:]
	if after, ok := strings.CutPrefix(rest, "SING-BOX "); ok {
		rec.Source, rest = SourceSingBox, after
	}
	word, message, _ := strings.Cut(rest, " ")
	if level, ok := ParseLevel(word); ok {
		rec.Level, rest = level.String(), strings.TrimLeft(message, " ")
	}
	rec.Msg = rest
	return rec
}

// knownKey reports whether a record key has its own field.
func knownKey(key string) bool {
	switch key {
	case "time", "level", "source", "msg", "message", "target", "op", "conn", "user", "code", "err", "notify", "caller", "stack":
		return true
	}
	return false
}

// parseJSON reads a flat JSON object into a record. Values that are not
// strings (numbers, booleans, nested objects) of unknown keys are kept as
// their JSON text.
func parseJSON(line []byte) (Record, bool) {
	rec := Record{}
	p := jsonParser{data: line}
	p.space()
	if !p.byte('{') {
		return rec, false
	}
	p.space()
	if p.byte('}') {
		return rec, true
	}
	for {
		p.space()
		key, ok := p.str()
		if !ok {
			return rec, false
		}
		p.space()
		if !p.byte(':') {
			return rec, false
		}
		p.space()
		var value string
		isString := p.peek() == '"'
		if isString {
			value, ok = p.str()
		} else {
			value, ok = p.raw()
		}
		if !ok {
			return rec, false
		}
		switch key {
		case "time":
			rec.Time, _ = time.Parse(time.RFC3339Nano, value)
		case "level":
			level, _ := ParseLevel(value)
			rec.Level = level.String()
		case "source":
			rec.Source = clean(value, true)
		case "msg":
			rec.Msg = clean(value, true)
		case "message": // older writers
			if rec.Msg == "" {
				rec.Msg = clean(value, true)
			}
		case "target":
			rec.Target = clean(value, true)
		case "op":
			rec.Op = clean(value, true)
		case "conn":
			rec.Conn = clean(value, true)
		case "user":
			rec.User = clean(value, true)
		case "code":
			rec.Code = clean(value, true)
		case "err":
			rec.Err = clean(value, true)
		case "notify":
			rec.Notify = value == "true"
		case "caller":
			rec.Caller = clean(value, true)
		case "stack":
			rec.Stack = cleanLines(value)
		default:
			if rec.Extra == nil {
				rec.Extra = map[string]string{}
			}
			rec.Extra[clean(key, true)] = clean(value, true)
		}
		p.space()
		if p.byte('}') {
			break
		}
		if !p.byte(',') {
			return rec, false
		}
	}
	if rec.Level == "" {
		rec.Level = "info"
	}
	return rec, true
}

// jsonParser reads the few JSON forms a log record uses.
type jsonParser struct {
	data []byte
	at   int
}

func (p *jsonParser) peek() byte {
	if p.at < len(p.data) {
		return p.data[p.at]
	}
	return 0
}

func (p *jsonParser) space() {
	for p.at < len(p.data) {
		switch p.data[p.at] {
		case ' ', '\t', '\r', '\n':
			p.at++
		default:
			return
		}
	}
}

func (p *jsonParser) byte(c byte) bool {
	if p.peek() == c {
		p.at++
		return true
	}
	return false
}

// str reads a JSON string.
func (p *jsonParser) str() (string, bool) {
	if !p.byte('"') {
		return "", false
	}
	start := p.at
	// The common case: no escapes.
	for p.at < len(p.data) {
		c := p.data[p.at]
		if c == '"' {
			p.at++
			return string(p.data[start : p.at-1]), true
		}
		if c == '\\' {
			break
		}
		p.at++
	}
	out := append([]byte(nil), p.data[start:p.at]...)
	for p.at < len(p.data) {
		c := p.data[p.at]
		switch {
		case c == '"':
			p.at++
			return string(out), true
		case c != '\\':
			out = append(out, c)
			p.at++
			continue
		}
		p.at++
		if p.at >= len(p.data) {
			return "", false
		}
		escaped := p.data[p.at]
		p.at++
		switch escaped {
		case '"', '\\', '/':
			out = append(out, escaped)
		case 'b':
			out = append(out, '\b')
		case 'f':
			out = append(out, '\f')
		case 'n':
			out = append(out, '\n')
		case 'r':
			out = append(out, '\r')
		case 't':
			out = append(out, '\t')
		case 'u':
			r, ok := p.hex4()
			if !ok {
				return "", false
			}
			if utf16.IsSurrogate(r) {
				second := utf8.RuneError
				if p.at+1 < len(p.data) && p.data[p.at] == '\\' && p.data[p.at+1] == 'u' {
					p.at += 2
					if second, ok = p.hex4(); !ok {
						return "", false
					}
				}
				r = utf16.DecodeRune(r, second)
			}
			out = utf8.AppendRune(out, r)
		default:
			return "", false
		}
	}
	return "", false
}

func (p *jsonParser) hex4() (rune, bool) {
	if p.at+4 > len(p.data) {
		return 0, false
	}
	value, err := strconv.ParseUint(string(p.data[p.at:p.at+4]), 16, 32)
	if err != nil {
		return 0, false
	}
	p.at += 4
	return rune(value), true //nolint:gosec // G115: four hex digits, at most 0xFFFF
}

// raw reads a non-string value (number, true, false, null, object, array) as its JSON text.
func (p *jsonParser) raw() (string, bool) {
	start, depth := p.at, 0
	for p.at < len(p.data) {
		c := p.data[p.at]
		switch c {
		case '"':
			if _, ok := p.str(); !ok {
				return "", false
			}
			continue
		case '{', '[':
			depth++
		case '}', ']':
			if depth == 0 {
				return strings.TrimSpace(string(p.data[start:p.at])), p.at > start
			}
			depth--
		case ',':
			if depth == 0 {
				return strings.TrimSpace(string(p.data[start:p.at])), p.at > start
			}
		}
		p.at++
	}
	return "", false
}

// Text is the record as one line for a terminal:
// "2026-10-29 01:02:03 ERROR server msg target=… code=… err=…" (local time).
func (rec Record) Text() string {
	var out strings.Builder
	if !rec.Time.IsZero() {
		out.WriteString(rec.Time.Local().Format("2006-01-02 15:04:05"))
		out.WriteByte(' ')
	}
	level := strings.ToUpper(rec.Level)
	out.WriteString(level)
	for range 5 - len(level) {
		out.WriteByte(' ')
	}
	out.WriteByte(' ')
	if rec.Source != "" && rec.Source != SourceServer {
		out.WriteString(rec.Source)
		out.WriteByte(' ')
	}
	out.WriteString(rec.Msg)
	for _, field := range rec.Fields() {
		out.WriteString(" " + field)
	}
	return out.String()
}

// Fields are the record's optional keys as key=value (the stack is left out).
func (rec Record) Fields() []string {
	var fields []string
	for _, field := range [...]struct{ key, value string }{
		{"target", rec.Target}, {"op", rec.Op}, {"conn", rec.Conn}, {"user", rec.User},
		{"code", rec.Code}, {"err", rec.Err}, {"caller", rec.Caller},
	} {
		if field.value != "" {
			fields = append(fields, field.key+"="+field.value)
		}
	}
	if rec.Notify {
		fields = append(fields, "notify=true")
	}
	for _, key := range sortedKeys(rec.Extra) {
		fields = append(fields, key+"="+rec.Extra[key])
	}
	return fields
}

func sortedKeys(m map[string]string) []string {
	if len(m) == 0 {
		return nil
	}
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	return keys
}
