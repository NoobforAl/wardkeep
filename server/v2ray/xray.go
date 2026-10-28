// Package v2ray reads an existing Xray/V2Ray *server* config so its users and
// its VLESS+Reality identity can be moved to an Wardkeep server. Keeping the
// Reality key, short ID and the users' UUIDs means the links the users
// already have keep working.
package v2ray

import (
	"crypto/ecdh"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// User is one client found in the config. Fields it did not have are empty.
type User struct {
	Name     string
	UUID     string // VLESS/VMess id
	Password string // Trojan password
	Note     string
}

// Reality is the VLESS+Reality identity of an inbound.
type Reality struct {
	PrivateKey, PublicKey, ShortID string
	// Handshake is host:port of the site it imitates.
	Handshake string
	Port      int
}

// Config is what could be taken from an Xray server config.
type Config struct {
	Users   []User
	Reality *Reality
	// Notes lists what was seen but cannot be carried over.
	Notes []string
}

type inbound struct {
	Tag      string `json:"tag"`
	Port     any    `json:"port"`
	Protocol string `json:"protocol"`
	Settings struct {
		Clients []struct {
			ID       string `json:"id"`
			Email    string `json:"email"`
			Password string `json:"password"`
			Flow     string `json:"flow"`
		} `json:"clients"`
	} `json:"settings"`
	Stream struct {
		Network  string `json:"network"`
		Security string `json:"security"`
		Reality  struct {
			Dest        string   `json:"dest"`
			Target      string   `json:"target"`
			ServerNames []string `json:"serverNames"`
			PrivateKey  string   `json:"privateKey"`
			ShortIDs    []string `json:"shortIds"`
		} `json:"realitySettings"`
	} `json:"streamSettings"`
}

var nameChars = regexp.MustCompile(`[^A-Za-z0-9._-]+`)

// Imported secrets end up inside text formats (.ovpn files, ShadowTLS plugin
// options, share links), so only plain characters are accepted: no
// whitespace, quotes, semicolons or control characters.
var (
	safeUUID     = regexp.MustCompile(`^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$`)
	safePassword = regexp.MustCompile(`^[A-Za-z0-9._~+=/:@!*,-]{1,128}$`)
)

// userName makes a valid, unique Wardkeep user name from an email (or a fallback).
func userName(email, fallback string, taken map[string]bool) string {
	name := email
	if i := strings.IndexByte(name, '@'); i > 0 {
		name = name[:i]
	}
	name = nameChars.ReplaceAllString(name, "-")
	name = strings.Trim(name, "-.")
	if name == "" {
		name = fallback
	}
	if len(name) > 28 {
		name = name[:28]
	}
	base, n := name, 2
	for taken[name] {
		name = base + "-" + strconv.Itoa(n)
		n++
	}
	taken[name] = true
	return name
}

func portOf(v any) int {
	switch p := v.(type) {
	case float64:
		return int(p)
	case string:
		n, _ := strconv.Atoi(p)
		return n
	}
	return 0
}

// PublicKey derives the Reality public key from a private key (both are
// base64url X25519 keys, as Xray prints them).
func PublicKey(private string) (string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(private, "="))
	if err != nil {
		return "", fmt.Errorf("Reality private key is not base64url: %w", err)
	}
	key, err := ecdh.X25519().NewPrivateKey(raw)
	if err != nil {
		return "", fmt.Errorf("Reality private key: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(key.PublicKey().Bytes()), nil
}

// ParseServer reads the inbounds of an Xray/V2Ray server config.
func ParseServer(text string) (*Config, error) {
	var doc struct {
		Inbounds []inbound `json:"inbounds"`
	}
	if err := json.Unmarshal([]byte(text), &doc); err != nil {
		return nil, fmt.Errorf("Xray config: %w", err)
	}
	cfg := &Config{}
	taken := map[string]bool{}
	byKey := map[string]int{} // uuid or password -> index in cfg.Users
	next := 1
	add := func(user User) {
		key := user.UUID + "|" + user.Password
		if _, ok := byKey[key]; ok {
			return
		}
		user.Name = userName(user.Name, "user"+strconv.Itoa(next), taken)
		next++
		byKey[key] = len(cfg.Users)
		cfg.Users = append(cfg.Users, user)
	}

	for _, in := range doc.Inbounds {
		switch strings.ToLower(in.Protocol) {
		case "vless", "vmess":
			for _, client := range in.Settings.Clients {
				switch {
				case client.ID == "":
				case !safeUUID.MatchString(client.ID):
					cfg.Notes = append(cfg.Notes, fmt.Sprintf("client %q skipped: its id is not a UUID", client.Email))
				default:
					add(User{Name: client.Email, UUID: client.ID, Note: "imported from " + in.Protocol})
				}
			}
			if strings.ToLower(in.Protocol) == "vmess" {
				cfg.Notes = append(cfg.Notes, "VMess inbound: users imported, but Wardkeep does not serve VMess (use VLESS+Reality)")
			}
			if in.Protocol == "vless" && in.Stream.Security == "reality" && cfg.Reality == nil {
				reality := in.Stream.Reality
				pub, err := PublicKey(reality.PrivateKey)
				if err != nil {
					cfg.Notes = append(cfg.Notes, err.Error())
					break
				}
				short := ""
				if len(reality.ShortIDs) > 0 {
					short = reality.ShortIDs[0]
				}
				dest := reality.Dest
				if dest == "" {
					dest = reality.Target
				}
				if dest != "" && !strings.Contains(dest, ":") {
					dest += ":443"
				}
				if dest == "" && len(reality.ServerNames) > 0 {
					dest = reality.ServerNames[0] + ":443"
				}
				cfg.Reality = &Reality{PrivateKey: reality.PrivateKey, PublicKey: pub, ShortID: short, Handshake: dest, Port: portOf(in.Port)}
			}
		case "trojan":
			for _, client := range in.Settings.Clients {
				switch {
				case client.Password == "":
				case !safePassword.MatchString(client.Password):
					cfg.Notes = append(cfg.Notes, fmt.Sprintf("trojan client %q skipped: its password has characters that are not allowed (letters, digits and ._~+=/:@!*,- only)", client.Email))
				default:
					add(User{Name: client.Email, Password: client.Password, Note: "imported from trojan"})
				}
			}
		case "shadowsocks":
			cfg.Notes = append(cfg.Notes, "Shadowsocks inbound skipped: Wardkeep issues its own Shadowsocks-2022 keys per user")
		case "":
		default:
			cfg.Notes = append(cfg.Notes, fmt.Sprintf("inbound %q (%s) is not carried over", in.Tag, in.Protocol))
		}
	}
	if len(cfg.Users) == 0 && cfg.Reality == nil {
		return nil, fmt.Errorf("no VLESS, VMess or Trojan clients found in the config")
	}
	return cfg, nil
}
