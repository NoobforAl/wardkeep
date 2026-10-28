// Package importer turns share links, config files and subscription bodies
// into profiles.
package importer

import (
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// ErrUnsupported is returned for input that no parser recognises.
var ErrUnsupported = errors.New("unsupported config format")

// ErrNoProfiles is returned when the text held links but none of them was valid.
var ErrNoProfiles = errors.New("no valid profiles")

// ErrXrayServer is returned for the config of an Xray server (not a client).
var ErrXrayServer = errors.New("this is an Xray server config; import it on the server (omnitun-server import xray), not as a client profile")

// UnsupportedError is a link of a scheme nothing here can read.
type UnsupportedError struct{ Scheme string }

func (e *UnsupportedError) Error() string { return ErrUnsupported.Error() + ": " + e.Scheme + "://" }

func (e *UnsupportedError) Unwrap() error { return ErrUnsupported }

// Result is the outcome of importing a blob of text.
type Result struct {
	Profiles []*profile.Profile `json:"profiles"`
	// Errors lists lines that looked like configs but failed to parse.
	Errors []string `json:"errors,omitempty"`
}

// Import detects the format of text and parses every profile it contains.
// Supported: share links (one per line), base64 subscription bodies, JSON
// (Xray, sing-box and SIP008 configs, a lone outbound, or a list of them; comments
// and trailing commas are tolerated), Clash YAML, OpenVPN and WireGuard/AmneziaWG
// .conf files. Text that is not valid JSON comes back as a *JSONError saying where.
func Import(text string) (*Result, error) {
	if len(text) > MaxTextSize {
		return nil, ErrTooLarge
	}
	text = strings.TrimSpace(strings.TrimPrefix(text, "\ufeff"))
	text = strings.TrimSpace(strings.TrimPrefix(stripFences(text), "\ufeff"))
	if text == "" {
		return nil, ErrUnsupported
	}
	if looksLikeJSON(text) {
		return importJSON(text)
	}
	if looksLikeClash(text) {
		return ImportClash(text)
	}
	if looksLikeOVPN(text) {
		prof, err := ParseOVPN(text)
		if err != nil {
			return nil, fmt.Errorf("openvpn: %w", err)
		}
		return &Result{Profiles: []*profile.Profile{prof}}, nil
	}
	if looksLikeWireGuardConf(text) {
		prof, err := ParseWireGuardConf(text)
		if err != nil {
			return nil, err
		}
		return &Result{Profiles: []*profile.Profile{prof}}, nil
	}
	if p := parseBridgeLines(text); p != nil {
		return &Result{Profiles: []*profile.Profile{p}}, nil
	}
	if !strings.Contains(text, "://") {
		if decoded, ok := decodeBase64(text); ok && strings.Contains(decoded, "://") {
			text = decoded
		}
	}
	res := &Result{}
	for line := range strings.SplitSeq(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
			continue
		}
		prof, err := ParseLink(line)
		if err != nil {
			res.Errors = append(res.Errors, fmt.Sprintf("%s: %v", truncate(line, 48), err))
			continue
		}
		res.Profiles = append(res.Profiles, prof)
	}
	if len(res.Profiles) == 0 {
		if len(res.Errors) > 0 {
			return res, fmt.Errorf("%w: %s", ErrNoProfiles, res.Errors[0])
		}
		return nil, ErrUnsupported
	}
	return res, nil
}

// ParseLink parses a single share link.
func ParseLink(link string) (*profile.Profile, error) {
	scheme, _, ok := strings.Cut(link, "://")
	if !ok {
		return nil, ErrUnsupported
	}
	var (
		prof *profile.Profile
		err  error
	)
	switch strings.ToLower(scheme) {
	case "vless":
		prof, err = parseVLESS(link)
	case "vmess":
		prof, err = parseVMess(link)
	case "trojan":
		prof, err = parseTrojan(link)
	case "ss":
		prof, err = parseShadowsocks(link)
	case "hysteria2", "hy2":
		prof, err = parseHysteria2(link)
	case "tuic":
		prof, err = parseTUIC(link)
	case "wireguard", "wg", "awg":
		prof, err = parseWireGuardLink(link)
	case "hysteria", "hy":
		prof, err = parseHysteria(link)
	case "anytls":
		prof, err = parseAnyTLS(link)
	case "ssh":
		prof, err = parseSSH(link)
	case "naive+https", "naive+quic", "naive":
		prof, err = parseNaive(link)
	case "ikev2":
		prof, err = parseIKEv2(link)
	case "sstp":
		prof, err = parseSSTP(link)
	case "tor":
		prof, err = parseTorLink(link)
	case "tailscale", "headscale":
		prof, err = parseTailscaleLink(link)
	case "dnstt":
		prof, err = parseDNSTT(link)
	default:
		return nil, &UnsupportedError{Scheme: scheme}
	}
	if err != nil {
		return nil, err
	}
	prof.Source = link
	if err := prof.Validate(); err != nil {
		return nil, err
	}
	prof.EnsureID()
	return prof, nil
}

// decodeBase64 accepts standard and URL alphabets, padded or not.
func decodeBase64(text string) (string, bool) {
	text = strings.Map(func(r rune) rune {
		if r == '\n' || r == '\r' || r == ' ' || r == '\t' {
			return -1
		}
		return r
	}, text)
	for _, enc := range []*base64.Encoding{
		base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding,
	} {
		if b, err := enc.DecodeString(text); err == nil {
			return string(b), true
		}
	}
	return "", false
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
