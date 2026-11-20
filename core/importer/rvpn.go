package importer

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"github.com/NoobforAl/wardkeep/core/profile"
)

// ErrRVPNNeedsServer is an rVPN prekey bundle on its own: it proves which server answers but does not say where the
// server is, so it is not a profile yet.
var ErrRVPNNeedsServer = errors.New("this is an rVPN server key (prekey-bundle.json) without the server address; " +
	"scan the rVPN QR code or paste the rvpn:// link instead")

// rvpnLinkVersion is the only link format version there is. A newer one may mean something else, so it is refused.
const rvpnLinkVersion = "1"

// parseRVPN reads an rvpn:// link (the format is in HOW-TO-CONNECT.md):
//
//	rvpn://<host>:<port><path>?v=1&ik=…&ixk=…&ixs=…&spk=…&pks=…&ikv=1[&otk=…][&rs=…][&alt=<host>,<host>]#<name>
//
// Keys are unpadded base64url; they become the standard padded base64 that prekey-bundle.json holds.
func parseRVPN(link string) (*profile.Profile, error) {
	u, err := url.Parse(link)
	if err != nil {
		return nil, fmt.Errorf("rvpn: not a link")
	}
	if u.User != nil {
		return nil, fmt.Errorf("rvpn: a link has no user name or password")
	}
	q := u.Query()
	if v := q.Get("v"); v != rvpnLinkVersion {
		if v == "" {
			return nil, fmt.Errorf("rvpn: the link has no format version (v=1)")
		}
		return nil, fmt.Errorf("rvpn: link format version %q is newer than this app; update the app", v)
	}
	host := u.Hostname()
	if host == "" {
		return nil, fmt.Errorf("rvpn: the link has no server")
	}
	port := 443
	if p := u.Port(); p != "" {
		port, err = strconv.Atoi(p)
		if err != nil || port <= 0 || port > 65535 {
			return nil, fmt.Errorf("rvpn: invalid port %q", p)
		}
	}
	path := u.EscapedPath()
	if path == "" || path == "/" {
		return nil, fmt.Errorf("rvpn: the link has no path (the server's secret WebSocket path)")
	}
	opts := &profile.RVPNOpts{Path: path}
	for _, k := range profile.RVPNKeys {
		raw := q.Get(k.Param)
		if raw == "" {
			continue
		}
		std, err := rvpnKey(raw, k.Size)
		if err != nil {
			return nil, fmt.Errorf("rvpn: key %s: %w", k.Param, err)
		}
		*k.Ptr(&opts.Bundle) = std
	}
	opts.Bundle.IdentityKeyVersion = 1
	if v := q.Get("ikv"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			return nil, fmt.Errorf("rvpn: invalid identity key version %q", v)
		}
		opts.Bundle.IdentityKeyVersion = n
	}
	if alt := q.Get("alt"); alt != "" {
		for h := range strings.SplitSeq(alt, ",") {
			if h = strings.TrimSpace(h); h != "" && !strings.EqualFold(h, host) {
				opts.Alt = append(opts.Alt, h)
			}
		}
	}
	name := u.Fragment
	if name == "" {
		name = "rVPN"
	}
	return &profile.Profile{Name: name, Protocol: profile.RVPN, Server: host, Port: port, RVPN: opts}, nil
}

// rvpnKey turns a link's key (base64url, padded or not) into the standard padded base64 of a bundle, checking
// its length.
func rvpnKey(raw string, size int) (string, error) {
	b, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(raw, "="))
	if err != nil {
		return "", fmt.Errorf("not base64url")
	}
	if len(b) != size {
		return "", fmt.Errorf("%d bytes, want %d", len(b), size)
	}
	return base64.StdEncoding.EncodeToString(b), nil
}

// rvpnServerRE finds the server address that goes with a pasted bundle: a wss:// URL, alone on a line or as
// client.toml's server_address.
var rvpnServerRE = regexp.MustCompile(`wss://[^\s"'<>]+`)

// importRVPNPair imports text that holds an rVPN prekey bundle (JSON) and the server's wss:// address next to it,
// such as connect.txt pasted together with prekey-bundle.json. ok is false when the text holds no bundle.
func importRVPNPair(text string) (res *Result, ok bool, err error) {
	start, end := strings.Index(text, "{"), strings.LastIndex(text, "}")
	if start < 0 || end < start {
		return nil, false, nil
	}
	// Text that is not one JSON object is not a bundle; the other importers say what is wrong with it.
	raw := []byte(text[start : end+1])
	if !json.Valid(raw) {
		return nil, false, nil
	}
	var obj map[string]json.RawMessage
	_ = json.Unmarshal(raw, &obj) // valid JSON that is not an object leaves obj empty, which is no bundle
	if !profile.LooksLikeRVPNBundle(obj) {
		return nil, false, nil
	}
	bundle, err := profile.ParseRVPNBundle(text[start : end+1])
	if err != nil {
		return nil, true, fmt.Errorf("rvpn: %w", err)
	}
	server := rvpnServerRE.FindString(text[:start] + "\n" + text[end+1:])
	if server == "" {
		return nil, true, ErrRVPNNeedsServer
	}
	u, err := url.Parse(server)
	if err != nil || u.Hostname() == "" {
		return nil, true, fmt.Errorf("rvpn: the server address is not a wss:// URL")
	}
	port := 443
	if p := u.Port(); p != "" {
		if port, err = strconv.Atoi(p); err != nil || port <= 0 || port > 65535 {
			return nil, true, fmt.Errorf("rvpn: invalid port %q", p)
		}
	}
	if bundle.IdentityKeyVersion == 0 {
		bundle.IdentityKeyVersion = 1
	}
	prof := &profile.Profile{
		Name: "rVPN", Protocol: profile.RVPN, Server: u.Hostname(), Port: port,
		RVPN: &profile.RVPNOpts{Path: u.EscapedPath(), Bundle: *bundle},
	}
	if err := prof.Validate(); err != nil {
		return nil, true, err
	}
	prof.EnsureID()
	return &Result{Profiles: []*profile.Profile{prof}}, true, nil
}
