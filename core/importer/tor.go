package importer

import (
	"fmt"
	"net/url"
	"slices"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

var torTransports = []string{"obfs4", "webtunnel", "snowflake", "meek_lite"}

// torBuiltinKinds are the built-in bridge sets a tor:// link can name.
var torBuiltinKinds = []string{"obfs4", "snowflake", "meek"}

// bridgeLine returns line without a torrc "Bridge " prefix and reports whether
// it looks like a Tor bridge line: "<transport> <addr> ..." or a plain
// "IP:PORT FINGERPRINT".
func bridgeLine(line string) (string, bool) {
	line = strings.TrimSpace(line)
	if rest, ok := strings.CutPrefix(line, "Bridge "); ok {
		line = strings.TrimSpace(rest)
	}
	f := strings.Fields(line)
	if len(f) < 2 {
		return "", false
	}
	if slices.Contains(torTransports, f[0]) {
		return line, true
	}
	if strings.Contains(f[0], ":") && len(f[1]) == 40 && !strings.Contains(f[0], "/") {
		return line, true
	}
	return "", false
}

// parseBridgeLines turns pasted bridge lines (as from bridges.torproject.org
// or a torrc) into one Tor profile. It returns nil if text isn't all bridges.
func parseBridgeLines(text string) *profile.Profile {
	var bridges []string
	for line := range strings.SplitSeq(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		b, ok := bridgeLine(line)
		if !ok {
			return nil
		}
		bridges = append(bridges, b)
	}
	if len(bridges) == 0 {
		return nil
	}
	p := &profile.Profile{
		Name:     "Tor (custom bridges)",
		Protocol: profile.Tor,
		Tor:      &profile.TorOpts{Bridges: bridges},
		Source:   "tor-bridges:" + strings.Join(bridges, "\n"),
	}
	p.EnsureID()
	return p
}

// parseTorLink parses tor:// (direct), tor://obfs4, tor://snowflake and tor://meek (Tor Browser's built-in
// bridges), and the same with the user's own bridges: tor://?bridge=<bridge line>&bridge=<another>. A fragment
// is the profile's name.
func parseTorLink(link string) (*profile.Profile, error) {
	_, rest, _ := strings.Cut(link, "://")
	rest, name, _ := strings.Cut(rest, "#")
	rest, rawQuery, _ := strings.Cut(rest, "?")
	kind := strings.ToLower(strings.Trim(rest, "/ "))
	p := &profile.Profile{Name: "Tor", Protocol: profile.Tor, Tor: &profile.TorOpts{}}
	if kind != "" {
		if !slices.Contains(torBuiltinKinds, kind) {
			return nil, fmt.Errorf("unknown Tor bridge kind %q (use obfs4, snowflake or meek)", kind)
		}
		p.Tor.Builtin = kind
		p.Name = "Tor (" + kind + ")"
	}
	if rawQuery != "" {
		q, err := url.ParseQuery(rawQuery)
		if err != nil {
			return nil, fmt.Errorf("bad Tor link: %v", err)
		}
		for _, b := range q["bridge"] {
			line, ok := bridgeLine(b)
			if !ok {
				return nil, fmt.Errorf("not a bridge line: %q", truncate(b, 48))
			}
			p.Tor.Bridges = append(p.Tor.Bridges, line)
		}
		if len(p.Tor.Bridges) > 0 && kind == "" {
			p.Name = "Tor (custom bridges)"
		}
	}
	if name, err := url.PathUnescape(name); err == nil && strings.TrimSpace(name) != "" {
		p.Name = strings.TrimSpace(name)
	}
	return p, nil
}
