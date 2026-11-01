package logrec

import (
	"net/netip"
	"regexp"
	"strings"
)

// Destinations, server addresses and ids never go into a log (docs/logging.md §1). Library errors carry them
// ("dial tcp 192.0.2.1:443: i/o timeout", "lookup example.com: no such host"), so text from outside the core is
// scrubbed before it is logged. Over-scrubbing an odd word is the safe side of the trade.
var scrubbers = []struct {
	pattern     *regexp.Regexp
	replacement string
	// replace, when set, decides for each whole-word match; with neither, a match goes through scrubHost.
	replace func(string) string
}{
	{pattern: regexp.MustCompile(`[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s"'<>]+`), replacement: "[url]"},
	// Secrets written as key=value (a bridge line's cert=, a password in a query string).
	{pattern: regexp.MustCompile(`(?i)\b(cert|password|passwd|pass|key|pubkey|token|secret|psk|auth|uuid|sni|url|front|fronts|ice)=[^\s,;"']+`), replacement: "${1}=[redacted]"},
	{pattern: regexp.MustCompile(`(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b`), replacement: "[uuid]"},
	{pattern: regexp.MustCompile(`\[[0-9a-fA-F:.%]*:[0-9a-fA-F:.%]*\](:\d{1,5})?`), replacement: "[addr]"},
	{pattern: regexp.MustCompile(`\b\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?\b`), replacement: "[addr]"},
	// MAC addresses (a router's, in sing-box's network messages): six pairs joined by ":" or "-".
	{pattern: regexp.MustCompile(`(?i)[0-9a-f]{2}[:-][0-9a-f]{2}(?:[:-][0-9a-f]{2}){4}`), replace: func(string) string { return "[mac]" }},
	// IPv6 addresses, full or compressed, with a zone or not. A run of hex digits and colons is one when it
	// parses as one, so times like 01:02:03 stay; checking each run, not a boundary character around it, also
	// catches two addresses side by side.
	{pattern: regexp.MustCompile(`(?i)[0-9a-f:]*:[0-9a-f:]*[0-9a-f:](%[0-9a-z_.\-]+)?`), replace: scrubIPv6},
	{pattern: regexp.MustCompile(`(?i)\b[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)*\.[a-z][a-z0-9\-]*[a-z0-9](:\d{1,5})?\b`)},
}

// fileSuffixes are dotted words that are file names, not hosts.
var fileSuffixes = []string{".go", ".rs", ".json", ".yaml", ".yml", ".toml", ".txt", ".db", ".dll", ".exe", ".so", ".log", ".conf", ".dat", ".ovpn", ".sock"}

// Scrub replaces addresses, host names, URLs and UUIDs in text.
func Scrub(text string) string {
	if text == "" {
		return text
	}
	for _, scrubber := range scrubbers {
		switch {
		case scrubber.replace != nil:
			text = replaceWords(text, scrubber.pattern, scrubber.replace)
		case scrubber.replacement != "":
			text = scrubber.pattern.ReplaceAllString(text, scrubber.replacement)
		default:
			text = scrubber.pattern.ReplaceAllStringFunc(text, scrubHost)
		}
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

// replaceWords replaces each match of pattern that is a whole word (no letter, digit or "_" right before or
// after it) by replace(match).
func replaceWords(text string, pattern *regexp.Regexp, replace func(string) string) string {
	var out strings.Builder
	last := 0
	for _, loc := range pattern.FindAllStringIndex(text, -1) {
		start, end := loc[0], loc[1]
		// A single colon at either end separates the match from its neighbour ("lookup fe80::1: no such host",
		// "x:fe80::1"); one of "::" belongs to an address.
		if end-start > 2 && text[start] == ':' && text[start+1] != ':' {
			start++
		}
		if end-start > 2 && text[end-1] == ':' && text[end-2] != ':' {
			end--
		}
		if (start > 0 && isWordByte(text[start-1])) || (end < len(text) && isWordByte(text[end])) {
			continue
		}
		out.WriteString(text[last:start])
		out.WriteString(replace(text[start:end]))
		last = end
	}
	out.WriteString(text[last:])
	return out.String()
}

func isWordByte(c byte) bool {
	return c == '_' || ('0' <= c && c <= '9') || ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')
}

// scrubIPv6 is "[addr]" for an IPv6 address, the run itself for anything else. A zone ("%eth0") is kept: it
// names an interface, not a place.
func scrubIPv6(run string) string {
	addr, zone, hasZone := strings.Cut(run, "%")
	if ip, err := netip.ParseAddr(addr); err != nil || !ip.Is6() {
		return run
	}
	if hasZone {
		return "[addr]%" + zone
	}
	return "[addr]"
}
