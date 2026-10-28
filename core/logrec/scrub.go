package logrec

import (
	"regexp"
	"strings"
)

// Destinations, server addresses and ids never go into a log (docs/logging.md §1). Library errors carry them
// ("dial tcp 192.0.2.1:443: i/o timeout", "lookup example.com: no such host"), so text from outside the core is
// scrubbed before it is logged. Over-scrubbing an odd word is the safe side of the trade.
var scrubbers = []struct {
	pattern     *regexp.Regexp
	replacement string
}{
	{regexp.MustCompile(`[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s"'<>]+`), "[url]"},
	// Secrets written as key=value (a bridge line's cert=, a password in a query string).
	{regexp.MustCompile(`(?i)\b(cert|password|passwd|pass|key|pubkey|token|secret|psk|auth|uuid|sni|url|front|fronts|ice)=[^\s,;"']+`), "${1}=[redacted]"},
	{regexp.MustCompile(`(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b`), "[uuid]"},
	{regexp.MustCompile(`\[[0-9a-fA-F:.%]*:[0-9a-fA-F:.%]*\](:\d{1,5})?`), "[addr]"},
	{regexp.MustCompile(`\b\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?\b`), "[addr]"},
	// Full IPv6 addresses (eight groups) and compressed ones (with "::"); times like 01:02:03 are left alone.
	{regexp.MustCompile(`(?i)(^|[^0-9a-z:_])(([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}|([0-9a-f]{1,4}(:[0-9a-f]{1,4})*)?::([0-9a-f]{1,4}(:[0-9a-f]{1,4})*)?)($|[^0-9a-z:_])`), "${1}[addr]${8}"},
	{regexp.MustCompile(`(?i)\b[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)*\.[a-z][a-z0-9\-]*[a-z0-9](:\d{1,5})?\b`), ""},
}

// fileSuffixes are dotted words that are file names, not hosts.
var fileSuffixes = []string{".go", ".rs", ".json", ".yaml", ".yml", ".toml", ".txt", ".db", ".dll", ".exe", ".so", ".log", ".conf", ".dat", ".ovpn", ".sock"}

// Scrub replaces addresses, host names, URLs and UUIDs in text.
func Scrub(text string) string {
	if text == "" {
		return text
	}
	for _, scrubber := range scrubbers {
		if scrubber.replacement != "" {
			text = scrubber.pattern.ReplaceAllString(text, scrubber.replacement)
			continue
		}
		text = scrubber.pattern.ReplaceAllStringFunc(text, scrubHost)
	}
	return text
}

func scrubHost(word string) string {
	lower := strings.ToLower(word)
	for _, suffix := range fileSuffixes {
		if strings.HasSuffix(lower, suffix) {
			return word
		}
	}
	// A Go identifier (context.Canceled, x509.Certificate) is not a host: hosts have no upper case after the dot.
	if dot := strings.LastIndexByte(word, '.'); dot >= 0 && word[dot+1:] != lower[dot+1:] {
		return word
	}
	return "[host]"
}
