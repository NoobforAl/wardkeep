package importer

import (
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"
)

// MaxTextSize is the most text Import reads (bytes); more is refused with ErrTooLarge instead of being parsed.
const MaxTextSize = 8 << 20

// ErrTooLarge is returned for text bigger than MaxTextSize.
var ErrTooLarge = errors.New("the text is too large to import")

// JSONError is text that looks like JSON but is not, and where the reader gave up.
type JSONError struct {
	// Line and Col are 1-based; Col counts characters, not bytes.
	Line, Col int
	// Found is the character that does not belong, quoted ('}'); empty when the text ends too early.
	Found string
}

func (e *JSONError) Error() string {
	if e.Found == "" {
		return fmt.Sprintf("invalid JSON: the text ends too early (line %d, column %d)", e.Line, e.Col)
	}
	return fmt.Sprintf("invalid JSON: unexpected %s at line %d, column %d", e.Found, e.Line, e.Col)
}

// NoServerError is JSON that is valid but holds no proxy server to import.
type NoServerError struct {
	// Found says what the JSON does hold ("outbounds: direct, block"), when it holds anything recognisable.
	Found string
}

func (e *NoServerError) Error() string {
	if e.Found == "" {
		return "this JSON has no proxy server in it"
	}
	return "this JSON has no proxy server in it (found " + e.Found + ")"
}

// looksLikeJSON reports whether text is meant to be JSON: an object or an array, perhaps after comments. A
// "[" that is followed by a word is a section of a .conf file ("[Interface]"), not an array.
func looksLikeJSON(text string) bool {
	t := strings.TrimSpace(relaxJSON(text))
	if strings.HasPrefix(t, "{") {
		return true
	}
	rest, ok := strings.CutPrefix(t, "[")
	if !ok {
		return false
	}
	rest = strings.TrimLeft(rest, " \t\r\n")
	return rest == "" || strings.ContainsRune(`{"[]-0123456789`, rune(rest[0]))
}

// stripFences removes the ```json … ``` wrapper that comes along when a config is copied from a chat or a
// web page.
func stripFences(text string) string {
	t := strings.TrimSpace(text)
	if !strings.HasPrefix(t, "```") {
		return text
	}
	_, rest, _ := strings.Cut(t, "\n")
	rest = strings.TrimSpace(rest)
	rest = strings.TrimSpace(strings.TrimSuffix(rest, "```"))
	return rest
}

// relaxJSON blanks what many tools write into JSON configs but the standard does not allow: // and /* */
// comments and a comma before a closing bracket. It replaces with spaces and keeps the line breaks, so every
// position in the result is the same as in the text.
func relaxJSON(text string) string {
	b := []byte(text)
	inString, escaped := false, false
	for i := 0; i < len(b); i++ {
		c := b[i]
		if inString {
			switch {
			case escaped:
				escaped = false
			case c == '\\':
				escaped = true
			case c == '"':
				inString = false
			}
			continue
		}
		switch {
		case c == '"':
			inString = true
		case c == '/' && i+1 < len(b) && b[i+1] == '/':
			for ; i < len(b) && b[i] != '\n'; i++ {
				b[i] = ' '
			}
			i--
		case c == '/' && i+1 < len(b) && b[i+1] == '*':
			end := strings.Index(string(b[i+2:]), "*/")
			stop := len(b)
			if end >= 0 {
				stop = i + 2 + end + 2
			}
			for ; i < stop; i++ {
				if b[i] != '\n' {
					b[i] = ' '
				}
			}
			i--
		}
	}
	// A trailing comma: the next thing after it that is not white space closes an object or an array.
	inString, escaped = false, false
	for i := 0; i < len(b); i++ {
		c := b[i]
		if inString {
			switch {
			case escaped:
				escaped = false
			case c == '\\':
				escaped = true
			case c == '"':
				inString = false
			}
			continue
		}
		if c == '"' {
			inString = true
			continue
		}
		if c != ',' {
			continue
		}
		j := i + 1
		for j < len(b) && (b[j] == ' ' || b[j] == '\t' || b[j] == '\r' || b[j] == '\n') {
			j++
		}
		if j < len(b) && (b[j] == '}' || b[j] == ']') {
			b[i] = ' '
		}
	}
	return string(b)
}

// jsonSyntax returns nil when text is valid JSON, and a *JSONError saying where it is not.
func jsonSyntax(text string) error {
	var v any
	err := json.Unmarshal([]byte(text), &v)
	if err == nil {
		return nil
	}
	var se *json.SyntaxError
	if !errors.As(err, &se) {
		return &JSONError{Line: 1, Col: 1, Found: "'?'"}
	}
	// Offset is the number of bytes read when the error came up; the offending one is the last of them.
	// When the text ends too early it is the length of the text, and there is no offending character.
	off := int(se.Offset)
	ended := strings.HasPrefix(se.Error(), "unexpected end")
	if ended {
		off = len(strings.TrimRight(text, " \t\r\n"))
	} else {
		off--
	}
	off = max(0, min(off, len(text)))
	line, col := 1, 1
	for i := 0; i < off; {
		r, n := utf8.DecodeRuneInString(text[i:])
		if r == '\n' {
			line++
			col = 1
		} else {
			col++
		}
		i += n
	}
	if ended {
		return &JSONError{Line: line, Col: col}
	}
	r, _ := utf8.DecodeRuneInString(text[off:])
	found := "'" + string(r) + "'"
	if r == '\n' || r == '\r' || r == '\t' {
		found = strconv.QuoteRune(r)
	}
	return &JSONError{Line: line, Col: col, Found: found}
}

// importJSON reads JSON text: a config or an outbound (Xray, sing-box, SIP008), a list of them, or a list of
// share links.
func importJSON(text string) (*Result, error) {
	text = relaxJSON(text)
	if err := jsonSyntax(text); err != nil {
		return nil, err
	}
	var doc any
	_ = json.Unmarshal([]byte(text), &doc)
	if list, ok := doc.([]any); ok {
		return importJSONList(list)
	}
	res, err := importJSONObject(text)
	return finishJSON(text, res, err)
}

// importJSONList imports every entry of a JSON array: configs, outbounds or share links; what fails is listed
// by its place in the array.
func importJSONList(list []any) (*Result, error) {
	res := &Result{}
	for i, item := range list {
		label := "#" + strconv.Itoa(i+1)
		switch v := item.(type) {
		case string:
			r, err := Import(v)
			if r != nil {
				res.Profiles = append(res.Profiles, r.Profiles...)
				for _, e := range r.Errors {
					res.Errors = append(res.Errors, label+": "+e)
				}
			}
			if err != nil && (r == nil || len(r.Errors) == 0) {
				res.Errors = append(res.Errors, label+": "+err.Error())
			}
		case map[string]any:
			raw, _ := json.Marshal(v)
			r, err := importJSONObject(string(raw))
			if r != nil {
				res.Profiles = append(res.Profiles, r.Profiles...)
				for _, e := range r.Errors {
					res.Errors = append(res.Errors, label+": "+e)
				}
			}
			if err != nil && (r == nil || len(r.Errors) == 0) {
				res.Errors = append(res.Errors, label+": "+err.Error())
			}
		default:
			res.Errors = append(res.Errors, label+": not a config, an outbound or a link")
		}
	}
	if len(res.Profiles) == 0 {
		if len(res.Errors) == 0 {
			return nil, &NoServerError{}
		}
		return res, fmt.Errorf("%w: %s", ErrNoProfiles, res.Errors[0])
	}
	return res, nil
}

// importJSONObject imports one JSON object: a config or a single outbound.
func importJSONObject(text string) (*Result, error) {
	if wrapped, ok := wrapBareOutbound(text); ok {
		text = wrapped
	}
	switch kindOfJSON(text) {
	case "sip008":
		return ImportSIP008(text)
	case "xray":
		return ImportXray(text)
	case "xray-server":
		return nil, ErrXrayServer
	}
	return ImportSingBoxJSON(text)
}

// finishJSON turns the failure of a sub-importer into one the app can explain: a server that was found but
// is wrong comes with its reasons in the result, JSON without any server says what it holds instead.
func finishJSON(text string, res *Result, err error) (*Result, error) {
	if err == nil || errors.Is(err, ErrXrayServer) {
		return res, err
	}
	if res != nil && len(res.Errors) > 0 {
		return res, fmt.Errorf("%w: %s", ErrNoProfiles, res.Errors[0])
	}
	return nil, &NoServerError{Found: describeJSON(text)}
}

// wrapBareOutbound makes {"outbounds":[…]} of a lone outbound, which is what people copy out of a config: an
// Xray one ({"protocol":"vless","settings":…}) or a sing-box one ({"type":"vless","server":…}).
func wrapBareOutbound(text string) (string, bool) {
	var m map[string]json.RawMessage
	if json.Unmarshal([]byte(text), &m) != nil {
		return "", false
	}
	for _, k := range []string{"outbounds", "endpoints", "inbounds", "servers", "extra_links"} {
		if _, ok := m[k]; ok {
			return "", false
		}
	}
	var protocol, typ string
	_ = json.Unmarshal(m["protocol"], &protocol)
	_ = json.Unmarshal(m["type"], &typ)
	if protocol == "" && !(typ != "" && (m["server"] != nil || m["peers"] != nil || m["server_port"] != nil)) {
		return "", false
	}
	return `{"outbounds":[` + text + `]}`, true
}

// describeJSON says what a JSON config holds, for the user who imported one without a proxy server in it:
// "outbounds: direct, block".
func describeJSON(text string) string {
	var doc map[string]json.RawMessage
	if json.Unmarshal([]byte(text), &doc) != nil {
		return ""
	}
	var parts []string
	for _, key := range []string{"outbounds", "endpoints", "inbounds"} {
		var entries []map[string]json.RawMessage
		_ = json.Unmarshal(doc[key], &entries)
		seen := map[string]bool{}
		for _, o := range entries {
			kind := jsonString(o["type"])
			if kind == "" {
				kind = jsonString(o["protocol"])
			}
			if kind != "" {
				seen[kind] = true
			}
		}
		if len(seen) == 0 {
			continue
		}
		names := make([]string, 0, len(seen))
		for k := range seen {
			names = append(names, k)
		}
		sort.Strings(names)
		parts = append(parts, key+": "+strings.Join(names, ", "))
	}
	return strings.Join(parts, "; ")
}
