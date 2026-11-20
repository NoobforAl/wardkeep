package links

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/NoobforAl/wardkeep/core/profile"
)

// rvpn writes the rvpn:// link of HOW-TO-CONNECT.md: keys as unpadded base64url, the parameters in the order the
// format lists them, and alt as a plain comma-separated list (host names need no escaping). The client's own
// identity key is never in a profile, so it cannot end up in the link.
func rvpn(prof *profile.Profile) (string, error) {
	opts := prof.RVPN
	if opts == nil {
		return "", fmt.Errorf("the profile has no rVPN settings")
	}
	if err := opts.Bundle.Check(); err != nil {
		return "", err
	}
	parts := []string{"v=1"}
	key := func(param, std string) {
		raw, _ := base64.StdEncoding.DecodeString(std) // Check has decoded every key already
		parts = append(parts, param+"="+base64.RawURLEncoding.EncodeToString(raw))
	}
	keys := map[string]string{}
	for _, k := range profile.RVPNKeys {
		keys[k.Param] = *k.Ptr(&opts.Bundle)
	}
	for _, p := range []string{"ik", "ixk", "ixs", "spk", "pks"} {
		key(p, keys[p])
	}
	version := max(opts.Bundle.IdentityKeyVersion, 1)
	parts = append(parts, "ikv="+strconv.Itoa(version))
	for _, p := range []string{"otk", "rs"} {
		if keys[p] != "" {
			key(p, keys[p])
		}
	}
	if len(opts.Alt) > 0 {
		alt := make([]string, len(opts.Alt))
		for i, h := range opts.Alt {
			alt[i] = url.QueryEscape(h)
		}
		parts = append(parts, "alt="+strings.Join(alt, ","))
	}
	name := prof.Name
	if name == "" {
		name = "rVPN"
	}
	return "rvpn://" + hostPort(prof) + opts.Path + "?" + strings.Join(parts, "&") + "#" + url.PathEscape(name), nil
}
