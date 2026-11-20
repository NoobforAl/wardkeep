package profile

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/netip"
	"strings"
)

// RVPNOpts configures an rVPN profile (github.com/PDG-Global/rvpn-core): an X3DH handshake, then the Double Ratchet,
// inside a WebSocket over TLS. Server and Port are the primary host; the connection is wss://Server:Port<Path>.
// The client's own identity key is not here: the rVPN helper makes one on the device the first time and keeps it
// there, so a profile (or a link made from it) never carries it.
type RVPNOpts struct {
	// Path is the server's secret WebSocket base path, starting with "/". Any other path gets a decoy page.
	Path string `json:"path"`
	// Alt are fallback hosts, tried in order. They share the port, the path and the bundle.
	Alt []string `json:"alt,omitempty"`
	// Bundle is the server's public prekey bundle: it proves which server answers.
	Bundle RVPNBundle `json:"bundle"`
}

// RVPNBundle is rVPN's prekey-bundle.json. Keys are standard padded base64, as rVPN writes them.
type RVPNBundle struct {
	IdentityKey             string `json:"identity_key"`
	IdentityX25519Key       string `json:"identity_x25519_key"`
	IdentityX25519Signature string `json:"identity_x25519_signature,omitempty"`
	SignedPrekey            string `json:"signed_prekey"`
	PrekeySignature         string `json:"prekey_signature"`
	OneTimePrekey           string `json:"one_time_prekey,omitempty"`
	IdentityKeyVersion      int    `json:"identity_key_version,omitempty"`
	RotationSignature       string `json:"rotation_signature,omitempty"`
}

// rvpnPort is the port an rVPN server listens on unless the link says otherwise.
const rvpnPort = 443

// RVPNKeyField is one key of the bundle: its name in prekey-bundle.json, its parameter in an rvpn:// link, its
// length in bytes, whether it must be there, and where it lives in RVPNBundle.
type RVPNKeyField struct {
	JSON, Param string
	Size        int
	Required    bool
	Ptr         func(*RVPNBundle) *string
}

// RVPNKeys lists the bundle's keys in the order rVPN writes them.
var RVPNKeys = []RVPNKeyField{
	{"identity_key", "ik", 32, true, func(b *RVPNBundle) *string { return &b.IdentityKey }},
	{"identity_x25519_key", "ixk", 32, true, func(b *RVPNBundle) *string { return &b.IdentityX25519Key }},
	{"identity_x25519_signature", "ixs", 64, true, func(b *RVPNBundle) *string { return &b.IdentityX25519Signature }},
	{"signed_prekey", "spk", 32, true, func(b *RVPNBundle) *string { return &b.SignedPrekey }},
	{"prekey_signature", "pks", 64, true, func(b *RVPNBundle) *string { return &b.PrekeySignature }},
	{"one_time_prekey", "otk", 32, false, func(b *RVPNBundle) *string { return &b.OneTimePrekey }},
	{"rotation_signature", "rs", 64, false, func(b *RVPNBundle) *string { return &b.RotationSignature }},
}

// Check reports the first key that is missing or of the wrong length. The identity X25519 signature is required:
// without it nothing ties the key the handshake uses to the server's identity.
func (b *RVPNBundle) Check() error {
	for _, k := range RVPNKeys {
		v := *k.Ptr(b)
		if v == "" {
			if k.Required {
				return fmt.Errorf("the server key %s is missing", k.JSON)
			}
			continue
		}
		raw, err := base64.StdEncoding.DecodeString(v)
		if err != nil || len(raw) != k.Size {
			return fmt.Errorf("the server key %s is not %d bytes of base64", k.JSON, k.Size)
		}
	}
	if b.IdentityKeyVersion < 0 {
		return fmt.Errorf("the identity key version cannot be negative")
	}
	return nil
}

// FileJSON is the bundle as rVPN's own prekey-bundle.json: every key present, the absent optional ones null, and the
// version defaulted to 1, which is what the rVPN helper reads.
func (b *RVPNBundle) FileJSON() ([]byte, error) {
	out := map[string]any{}
	for _, k := range RVPNKeys {
		if v := *k.Ptr(b); v != "" {
			out[k.JSON] = v
		} else {
			out[k.JSON] = nil
		}
	}
	version := b.IdentityKeyVersion
	if version == 0 {
		version = 1
	}
	out["identity_key_version"] = version
	return json.MarshalIndent(out, "", "  ")
}

// ParseRVPNBundle reads a prekey-bundle.json. Unknown keys are ignored; the keys are checked.
func ParseRVPNBundle(text string) (*RVPNBundle, error) {
	var b RVPNBundle
	dec := json.NewDecoder(strings.NewReader(text))
	if err := dec.Decode(&b); err != nil {
		return nil, fmt.Errorf("not an rVPN prekey bundle: %w", err)
	}
	if err := b.Check(); err != nil {
		return nil, err
	}
	return &b, nil
}

// LooksLikeRVPNBundle reports whether a JSON object is an rVPN prekey bundle (it has the keys only rVPN uses).
func LooksLikeRVPNBundle(obj map[string]json.RawMessage) bool {
	_, ik := obj["identity_key"]
	_, ixk := obj["identity_x25519_key"]
	_, spk := obj["signed_prekey"]
	return ik && ixk && spk
}

func rvpnOf(profile *Profile, create bool) *RVPNOpts {
	if profile.RVPN == nil && create {
		profile.RVPN = &RVPNOpts{}
	}
	return profile.RVPN
}

// validRVPNPath reports whether p is a usable WebSocket path: it starts with "/" and holds no query, fragment,
// space or control character, which would change the request line.
func validRVPNPath(p string) bool {
	if !strings.HasPrefix(p, "/") || len(p) > 512 {
		return false
	}
	for _, r := range p {
		if r <= ' ' || r == 0x7f || r == '?' || r == '#' || r == '\\' {
			return false
		}
	}
	return true
}

// validateRVPN checks an rVPN profile when it is made or edited.
func validateRVPN(profile *Profile) error {
	opts := profile.RVPN
	if opts == nil {
		return fmt.Errorf("profile %q: missing rVPN settings", profile.Name)
	}
	if _, err := netip.ParseAddr(profile.Server); err == nil || !validDomain(profile.Server) {
		return fmt.Errorf("profile %q: the rVPN server must be a host name (its certificate is checked against it)", profile.Name)
	}
	if !validRVPNPath(opts.Path) {
		return fmt.Errorf("profile %q: the rVPN path must start with / and have no spaces, ? or #", profile.Name)
	}
	for _, h := range opts.Alt {
		if !validDomain(h) {
			return fmt.Errorf("profile %q: the fallback %q is not a host name", profile.Name, h)
		}
	}
	if err := opts.Bundle.Check(); err != nil {
		return fmt.Errorf("profile %q: %w", profile.Name, err)
	}
	return nil
}

func rvpnFields() []Field {
	bundle := Field{
		Key: "rvpn.bundle", Label: "Server key (prekey-bundle.json)", Kind: FieldMultiline, Required: true,
		Help: "The contents of the server's prekey-bundle.json",
		get: func(p *Profile) string {
			if p.RVPN == nil || p.RVPN.Bundle.IdentityKey == "" {
				return ""
			}
			b, err := p.RVPN.Bundle.FileJSON()
			if err != nil {
				return ""
			}
			return string(b)
		},
		set: func(p *Profile, v string) error {
			v = strings.TrimSpace(v)
			if v == "" {
				if p.RVPN != nil {
					p.RVPN.Bundle = RVPNBundle{}
				}
				return nil
			}
			b, err := ParseRVPNBundle(v)
			if err != nil {
				return err
			}
			rvpnOf(p, true).Bundle = *b
			return nil
		},
	}
	return []Field{
		text("rvpn.path", "Path", func(p *Profile, c bool) *string {
			if o := rvpnOf(p, c); o != nil {
				return &o.Path
			}
			return nil
		}, required, help("The server's secret WebSocket path, such as /api/v1/ws")),
		bundle,
		list("rvpn.alt", "Fallback servers", func(p *Profile, c bool) *[]string {
			if o := rvpnOf(p, c); o != nil {
				return &o.Alt
			}
			return nil
		}, ", ", advanced, help("Other names of the same server, tried in order when the first does not answer")),
	}
}
