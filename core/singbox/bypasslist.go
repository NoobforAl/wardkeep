package singbox

import (
	"fmt"
	"net/netip"
	"regexp"
	"strings"
)

// MaxBypassEntries bounds the names (domains, keywords, expressions) of a bypass
// list so a huge file cannot slow every connection down or bloat the configuration.
const MaxBypassEntries = 50000

// MaxBypassRanges bounds the addresses and ranges of a list separately: a
// country's ranges (the app can add whole countries) are tens of thousands of
// entries, and an address range costs one lookup in a sorted set, not a scan
// like a name expression does.
const MaxBypassRanges = 1000000

// BypassList is a set of destinations that go around the VPN (or, with
// Options.BypassOnly, the only ones that use it). Written one entry per line:
//
//	example.com            the domain and its subdomains
//	domain:example.com     the same
//	full:www.example.com   exactly this name
//	keyword:bank           any name containing this word
//	regexp:^ads?\..*       names matching the expression
//	203.0.113.7            an address
//	10.0.0.0/8             a range (IPv4 or IPv6)
//
// Blank lines and anything after # are ignored.
type BypassList struct {
	Suffix  []string
	Full    []string
	Keyword []string
	Regex   []string
	CIDRs   []netip.Prefix
}

// Empty reports whether the list has no entries.
func (b *BypassList) Empty() bool { return b == nil || b.Count() == 0 }

// Count is the number of entries.
func (b *BypassList) Count() int {
	if b == nil {
		return 0
	}
	return len(b.Suffix) + len(b.Full) + len(b.Keyword) + len(b.Regex) + len(b.CIDRs)
}

// BypassIssue is one line of a list that could not be used.
type BypassIssue struct {
	Line    int    `json:"line"` // 1-based
	Text    string `json:"text"`
	Message string `json:"message"`
	// Code names Message for translation (the Bypass* constants); Limit is the
	// number in BypassTooMany.
	Code  string `json:"code,omitempty"`
	Limit int    `json:"limit,omitempty"`
}

// Codes of the problems a line of a bypass list can have.
const (
	BypassEmptyExpression = "EMPTY_EXPRESSION"
	BypassBadExpression   = "BAD_EXPRESSION"
	BypassBadName         = "BAD_NAME"
	BypassGeoUnsupported  = "GEO_UNSUPPORTED"
	BypassBadEntry        = "BAD_ENTRY"
	BypassTooMany         = "TOO_MANY"
)

func (i BypassIssue) Error() string {
	return fmt.Sprintf("line %d: %s (%s)", i.Line, i.Message, i.Text)
}

// ParseBypassList reads a list. Lines that cannot be used are reported and
// skipped; the rest of the list still counts.
func ParseBypassList(text string) (*BypassList, []BypassIssue) {
	var list BypassList
	var issues []BypassIssue
	seen := map[string]bool{}
	for n, raw := range strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n") {
		line := raw
		if i := strings.IndexByte(line, '#'); i >= 0 {
			line = line[:i]
		}
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		bad := func(code, msg string) {
			issues = append(issues, BypassIssue{Line: n + 1, Text: clip(raw), Message: msg, Code: code})
		}
		if names := len(list.Suffix) + len(list.Full) + len(list.Keyword) + len(list.Regex); names >= MaxBypassEntries {
			bad(BypassTooMany, fmt.Sprintf("more than %d entries: the rest is ignored", MaxBypassEntries))
			issues[len(issues)-1].Limit = MaxBypassEntries
			break
		} else if len(list.CIDRs) >= MaxBypassRanges {
			bad(BypassTooMany, fmt.Sprintf("more than %d entries: the rest is ignored", MaxBypassRanges))
			issues[len(issues)-1].Limit = MaxBypassRanges
			break
		}
		if seen[strings.ToLower(line)] {
			continue
		}
		seen[strings.ToLower(line)] = true

		kind, value, hasKind := strings.Cut(line, ":")
		switch {
		case hasKind && strings.EqualFold(kind, "regexp"):
			value = strings.TrimSpace(value)
			if value == "" {
				bad(BypassEmptyExpression, "empty expression")
			} else if _, err := regexp.Compile(value); err != nil {
				bad(BypassBadExpression, "not a valid expression")
			} else {
				list.Regex = append(list.Regex, value)
			}
		case hasKind && (strings.EqualFold(kind, "full") || strings.EqualFold(kind, "domain") || strings.EqualFold(kind, "keyword")):
			value = strings.ToLower(strings.TrimSpace(value))
			if !validName(value, strings.EqualFold(kind, "keyword")) {
				bad(BypassBadName, "not a valid name")
				continue
			}
			switch strings.ToLower(kind) {
			case "full":
				list.Full = append(list.Full, value)
			case "domain":
				list.Suffix = append(list.Suffix, value)
			default:
				list.Keyword = append(list.Keyword, value)
			}
		case hasKind && (strings.EqualFold(kind, "geosite") || strings.EqualFold(kind, "geoip")):
			bad(BypassGeoUnsupported, "geo lists are not supported; list the domains or ranges")
		default:
			if p, err := netip.ParsePrefix(line); err == nil {
				list.CIDRs = append(list.CIDRs, p.Masked())
			} else if a, err := netip.ParseAddr(line); err == nil {
				list.CIDRs = append(list.CIDRs, netip.PrefixFrom(a.Unmap(), a.Unmap().BitLen()))
			} else if name := strings.ToLower(strings.TrimPrefix(line, ".")); validName(name, false) {
				list.Suffix = append(list.Suffix, name)
			} else {
				bad(BypassBadEntry, "not a domain, address or range")
			}
		}
	}
	return &list, issues
}

var nameRE = regexp.MustCompile(`^[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?(\.[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?)*$`)

// validName accepts host names (letters, digits, '-', '_', dots); a keyword
// may be any such word, also without a dot.
func validName(name string, keyword bool) bool {
	if name == "" || len(name) > 253 {
		return false
	}
	if keyword {
		return nameRE.MatchString(strings.ReplaceAll(name, ".", "a"))
	}
	// A name whose last part is all digits is a mistyped address, not a domain.
	last := name[strings.LastIndexByte(name, '.')+1:]
	if strings.Trim(last, "0123456789") == "" {
		return false
	}
	return nameRE.MatchString(name)
}

func clip(s string) string {
	s = strings.TrimSpace(s)
	if len(s) > 80 {
		return s[:80] + "…"
	}
	return s
}

// rules are the sing-box rule bodies for the list: one per kind of entry,
// because the fields of one sing-box rule must all match.
func (b *BypassList) rules() []map[string]any {
	if b.Empty() {
		return nil
	}
	var out []map[string]any
	add := func(key string, v any, n int) {
		if n > 0 {
			out = append(out, map[string]any{key: v})
		}
	}
	add("domain_suffix", b.Suffix, len(b.Suffix))
	add("domain", b.Full, len(b.Full))
	add("domain_keyword", b.Keyword, len(b.Keyword))
	add("domain_regex", b.Regex, len(b.Regex))
	add("ip_cidr", prefixStrings(b.CIDRs), len(b.CIDRs))
	return out
}

// OnlyRanges reports whether the list holds addresses and ranges only, few
// enough to be routes of their own. Then "only these use the VPN" needs no
// name matching, and the rest of the traffic can stay out of the tunnel.
func (b *BypassList) OnlyRanges() bool {
	if b.Empty() || len(b.Suffix)+len(b.Full)+len(b.Keyword)+len(b.Regex) > 0 {
		return false
	}
	return len(MergePrefixes(b.CIDRs)) <= RouteBudget
}

// addressRules are the rules that match addresses only; they need no packet
// inspection, so they run before the names do.
func (b *BypassList) addressRules() []map[string]any {
	var out []map[string]any
	for _, r := range b.rules() {
		if _, ip := r["ip_cidr"]; ip {
			out = append(out, r)
		}
	}
	return out
}

// domainRules are the rules that match names only (what DNS rules can use).
func (b *BypassList) domainRules() []map[string]any {
	var out []map[string]any
	for _, r := range b.rules() {
		if _, ip := r["ip_cidr"]; !ip {
			out = append(out, r)
		}
	}
	return out
}
