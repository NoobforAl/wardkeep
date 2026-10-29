// Package hostproto runs the protocols that sing-box does not serve:
// AmneziaWG (amneziawg-go), which needs a TUN device and NAT on the host, so it
// works on Linux with CAP_NET_ADMIN (or root) — the installer grants the
// capability and enables IP forwarding — and the DNSCrypt resolver.
package hostproto

import (
	"fmt"
	"time"

	"github.com/NoobforAl/omnitun/core/protocols"
)

// Config is what a host server needs.
type Config struct {
	// Env carries the server's address and keys.
	Env  protocols.Env
	Port int
	// Users are the active accounts (name and password).
	Users []protocols.Account
	// Runner runs host commands (the AmneziaWG interface address); nil means
	// real commands.
	Runner Runner
	// Logf receives the servers' own error messages.
	Logf func(format string, args ...any)
	// DNSRotateEvery is how often the DNSCrypt resolver's short-term key and
	// certificate are replaced (default 7 days).
	DNSRotateEvery time.Duration
}

// Server is a running host-level server.
type Server interface {
	// Close stops it and releases its TUN device.
	Close() error
	// Pool is the tunnel network its clients get (NAT has to cover it).
	Pool() string
}

// Usage is what one user moved through a host server since it started:
// Up from the client, Down to the client, in bytes of tunnelled traffic.
type Usage struct {
	User     string
	Up, Down uint64
	// Sessions is how many connections the user has right now.
	Sessions int
}

// DualStack is implemented by the host servers that also give clients an IPv6
// address; its network has to be covered by NAT like the IPv4 one.
type DualStack interface {
	// Pool6 is the IPv6 tunnel network, or "" when this run has none.
	Pool6() string
}

// Meter is implemented by the host servers that count traffic per user.
// Usage is cumulative since the server started (it never goes down while the
// server runs), so a reader works out what is new by keeping the last values.
type Meter interface {
	Usage() []Usage
}

// Keys lists the protocols this package serves.
func Keys() []string { return []string{"amneziawg", "dnscrypt"} }

// Start starts the host server for a protocol key. The server runs in the
// background; Start returns once it is listening or has failed.
func Start(key string, cfg Config) (Server, error) {
	// The DNSCrypt resolver has no accounts: it answers whoever reaches it.
	if len(cfg.Users) == 0 && key != "dnscrypt" {
		return nil, fmt.Errorf("%s: no active users", key)
	}
	switch key {
	case "dnscrypt":
		return startDNSCrypt(cfg)
	case "amneziawg":
		return startAWG(cfg)
	}
	return nil, fmt.Errorf("%q is not a host-level protocol", key)
}
