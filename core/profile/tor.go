package profile

import (
	"fmt"
	"regexp"
	"strings"
)

// bridgeFingerprint finds the relay fingerprint of a bridge line: Arti will not use a bridge without one.
var bridgeFingerprint = regexp.MustCompile(`(?i)(^|\s)(fingerprint=)?[0-9a-f]{40}(\s|$)`)

// validateTor checks a Tor profile when it is made or edited, so a bad bridge is reported then and not as a
// failed connection later.
func validateTor(profile *Profile) error {
	if profile.Tor == nil {
		return nil
	}
	switch profile.Tor.Builtin {
	case "", "obfs4", "snowflake", "meek":
	default:
		return fmt.Errorf("profile %q: unknown built-in bridge kind %q (use obfs4, snowflake or meek)", profile.Name, profile.Tor.Builtin)
	}
	for i, bridge := range profile.Tor.Bridges {
		bridge = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(bridge), "Bridge "))
		if bridge == "" {
			return fmt.Errorf("profile %q: bridge line %d is empty", profile.Name, i+1)
		}
		if !bridgeFingerprint.MatchString(bridge) {
			return fmt.Errorf("profile %q: bridge line %d has no relay fingerprint (40 hexadecimal characters)", profile.Name, i+1)
		}
	}
	return nil
}
