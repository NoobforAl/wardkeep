package killswitch

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// Resolver looks up the addresses of a host name.
type Resolver func(ctx context.Context, host string) ([]netip.Addr, error)

// SystemResolver uses the operating system's resolver. Call it before the
// tunnel is up: afterwards the answer would come through the tunnel.
func SystemResolver(ctx context.Context, host string) ([]netip.Addr, error) {
	return net.DefaultResolver.LookupNetIP(ctx, "ip", host)
}

// Unsupported lists protocols whose traffic the kill switch cannot recognise:
// they do not run in the sing-box tunnel adapter, or their helper programs
// open sockets to unknown addresses.
var unsupported = map[string]bool{
	profile.Tor:       true,
	profile.IKEv2:     true,
	profile.SSTP:      true,
	profile.AmneziaWG: true,
	profile.DNSTT:     true, // its helper sockets go to resolvers the kill switch does not know
}

// CheckProfiles refuses a profile set the kill switch cannot protect.
func CheckProfiles(profiles []*profile.Profile) error {
	for _, p := range profiles {
		if unsupported[p.Protocol] {
			return fmt.Errorf("the kill switch does not work with %s profiles yet (%s)", p.Protocol, p.DisplayName())
		}
	}
	return nil
}

// ServerAddrs returns the addresses of every server named in profiles
// (including OpenVPN's further remotes), de-duplicated, in first-seen order.
// A host that does not resolve is an error: it would be blocked.
func ServerAddrs(ctx context.Context, profiles []*profile.Profile, resolve Resolver) ([]netip.Addr, error) {
	var out []netip.Addr
	seen := map[netip.Addr]bool{}
	add := func(host string) error {
		host = strings.Trim(strings.TrimSpace(host), "[]")
		if host == "" {
			return nil
		}
		var addrs []netip.Addr
		if a, err := netip.ParseAddr(host); err == nil {
			addrs = []netip.Addr{a}
		} else {
			var rerr error
			if addrs, rerr = resolve(ctx, host); rerr != nil {
				return fmt.Errorf("resolve %s: %w", host, rerr)
			}
		}
		for _, a := range addrs {
			a = a.Unmap().WithZone("")
			if !seen[a] {
				seen[a] = true
				out = append(out, a)
			}
		}
		return nil
	}
	for _, p := range profiles {
		if err := add(p.Server); err != nil {
			return nil, err
		}
		if p.OpenVPN != nil {
			for _, r := range p.OpenVPN.Remotes {
				if err := add(r.Server); err != nil {
					return nil, err
				}
			}
		}
	}
	return out, nil
}
