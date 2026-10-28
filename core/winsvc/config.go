package winsvc

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
)

// Config is the service's settings, stored in Layout.Config. Only SYSTEM and
// Administrators can change the file.
type Config struct {
	// AllowedSIDs are the user accounts (security identifiers) that may read
	// the control file and so drive the VPN.
	AllowedSIDs []string `json:"allowed_sids"`
}

var sidPattern = regexp.MustCompile(`^S-1-\d+(-\d+){1,15}$`)

// ValidSID reports whether s looks like a security identifier. It is what
// keeps anything else out of the access-control string built from the list.
func ValidSID(s string) bool { return sidPattern.MatchString(s) }

// Validate checks the configuration.
func (c *Config) Validate() error {
	if len(c.AllowedSIDs) == 0 {
		return errors.New("no user is allowed to use the service")
	}
	for _, s := range c.AllowedSIDs {
		if !ValidSID(s) {
			return fmt.Errorf("%q is not a security identifier", s)
		}
	}
	return nil
}

// Add allows a user, once.
func (c *Config) Add(sid string) {
	if !slices.Contains(c.AllowedSIDs, sid) {
		c.AllowedSIDs = append(c.AllowedSIDs, sid)
	}
}

// LoadConfig reads the settings; a missing file is an empty configuration.
func LoadConfig(path string) (Config, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return Config{}, nil
	}
	if err != nil {
		return Config{}, err
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return Config{}, fmt.Errorf("%s: %w", path, err)
	}
	return cfg, nil
}

// SaveConfig writes the settings.
func SaveConfig(path string, cfg Config) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// Well-known SIDs.
const (
	sidSystem         = "S-1-5-18"
	sidAdministrators = "S-1-5-32-544"
)

// ControlDirSDDL is the owner (Administrators) and access-control list of the control directory:
// protected (nothing inherited from ProgramData, which lets every user read),
// SYSTEM and Administrators full control, the allowed users read-only. Files
// created inside inherit it, so the control file is never readable by anyone
// else, not even for an instant.
func ControlDirSDDL(sids []string) (string, error) {
	c := Config{AllowedSIDs: sids}
	if err := c.Validate(); err != nil {
		return "", err
	}
	var sddl strings.Builder
	sddl.WriteString("O:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)")
	for _, s := range sids {
		if s == sidSystem || s == sidAdministrators {
			continue // already there
		}
		sddl.WriteString("(A;OICI;FR;;;" + s + ")")
	}
	return sddl.String(), nil
}

// RootSDDL is the owner (Administrators) and access-control list of %ProgramData%\omnitun: SYSTEM and
// Administrators only.
const RootSDDL = "O:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"

// trustedOwners may own the directories of the service: SYSTEM (the service
// itself) and Administrators (the installer). The owner of a directory can
// always rewrite its access list, so a directory that somebody else created,
// and still owns, must never be adopted (see SecureDir).
var trustedOwners = []string{sidSystem, sidAdministrators}

// OwnerTrusted reports whether a directory owned by sid may be used.
func OwnerTrusted(sid string) bool { return slices.Contains(trustedOwners, sid) }
