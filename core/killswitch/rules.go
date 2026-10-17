// Package killswitch blocks every packet that does not use the VPN tunnel
// while the tunnel is meant to be up, so a dropped connection (or a crashed
// tunnel) never sends traffic around it.
//
// The package is split in three:
//
//   - rules.go: Build turns Options (server addresses, the tunnel adapter, a
//     few switches) into a plain list of Rule values. Pure Go, no operating
//     system calls; this is what the unit tests check.
//   - manager.go: Manager arms and disarms a rule set through a Backend and
//     remembers what is armed.
//   - wfp_windows.go: the Backend for the Windows Filtering Platform. Other
//     systems get a stub that reports ErrUnsupported.
//
// The rules follow the usual shape of a Windows VPN kill switch (WireGuard for
// Windows and Mullvad do the same): one low-weight "block everything" rule and
// a set of higher-weight "permit" rules for what must keep working.
package killswitch

import (
	"errors"
	"fmt"
	"net/netip"
	"slices"
)

// Direction of a rule: a new outgoing connection or packet flow
// (ALE_AUTH_CONNECT in WFP) or a new incoming one (ALE_AUTH_RECV_ACCEPT).
type Direction uint8

const (
	Outbound Direction = iota + 1
	Inbound
)

func (d Direction) String() string {
	switch d {
	case Outbound:
		return "out"
	case Inbound:
		return "in"
	}
	return "?"
}

// Family is the IP version a rule applies to.
type Family uint8

const (
	IPv4 Family = 4
	IPv6 Family = 6
)

// Action of a rule.
type Action uint8

const (
	Permit Action = iota + 1
	Block
)

func (a Action) String() string {
	switch a {
	case Permit:
		return "permit"
	case Block:
		return "block"
	}
	return "?"
}

// Field is the part of a connection a Condition looks at.
type Field uint8

const (
	// RemoteAddress matches the remote address; Values are netip.Prefix.
	RemoteAddress Field = iota + 1
	// Loopback matches loopback traffic; it has no values.
	Loopback
	// LocalInterface matches the interface the traffic uses; one uint64 value (the LUID).
	LocalInterface
	// Application matches the program that owns the socket; Values are file paths.
	Application
	// Protocol matches the IP protocol number; Values are uint8.
	Protocol
	// LocalPort and RemotePort match ports; Values are uint16. For ICMP the
	// local "port" is the message type (that is how WFP exposes it).
	LocalPort
	RemotePort
)

func (f Field) String() string {
	switch f {
	case RemoteAddress:
		return "remote-address"
	case Loopback:
		return "loopback"
	case LocalInterface:
		return "local-interface"
	case Application:
		return "application"
	case Protocol:
		return "protocol"
	case LocalPort:
		return "local-port"
	case RemotePort:
		return "remote-port"
	}
	return "?"
}

// IP protocol numbers used by the rules.
const (
	ProtoICMPv6 uint8 = 58
	ProtoUDP    uint8 = 17
)

// Condition is one test of a rule. Several Values of one Condition are
// alternatives (any of them); the Conditions of a rule must all hold.
type Condition struct {
	Field  Field
	Values []any
}

// Rule is one filter. Within the kill switch's sublayer a rule with a higher
// Weight is looked at first and the first permit or block decides.
type Rule struct {
	Name       string
	Direction  Direction
	Family     Family
	Action     Action
	Weight     uint64
	Conditions []Condition
}

// Weights, highest first. Block is the lowest so any permit beats it.
const (
	weightLoopback = 1000 - iota*10
	weightTunnel
	weightApps
	weightServers
	weightProtocols
	weightLAN
	weightRanges
	weightBlock = 1
)

// MaxRanges is how many extra "allowed" address ranges (the user's bypass
// list) a kill switch takes. Every range is part of a firewall rule, and the
// firewall is not built for hundreds of thousands of them; a country list is
// far above this. The caller is told, never silently cut.
const MaxRanges = 4096

// rangesPerRule splits long address lists over several rules.
const rangesPerRule = 256

// ErrTooManyRanges is returned when AllowRanges exceeds MaxRanges.
var ErrTooManyRanges = errors.New("killswitch: too many address ranges to allow")

// Options describes what must keep working while everything else is blocked.
type Options struct {
	// ServerAddrs are the VPN servers' addresses (already resolved). Traffic to
	// them is permitted on any interface, because the tunnel itself runs over it.
	ServerAddrs []netip.Addr

	// TunLUID is the tunnel adapter's locally unique identifier. Zero means the
	// tunnel does not exist yet ("block while connecting"): only the server,
	// the programs and the other permits below are open.
	TunLUID uint64

	// Apps are programs whose own traffic is permitted: the core itself (its
	// sockets are the tunnel's outer connection and the deliberately direct
	// ones of the bypass list) and helpers such as the Tor client.
	Apps []string

	// AllowLAN also permits local networks (private ranges, link-local,
	// multicast). The tunnel does not route them either, unless the user chose to.
	AllowLAN bool

	// AllowRanges are further ranges that bypass the tunnel on purpose (the
	// user's bypass list). At most MaxRanges.
	AllowRanges []netip.Prefix
}

// Validate checks the options.
func (o *Options) Validate() error {
	if len(o.AllowRanges) > MaxRanges {
		return fmt.Errorf("%w: %d (at most %d)", ErrTooManyRanges, len(o.AllowRanges), MaxRanges)
	}
	for _, a := range o.ServerAddrs {
		if !a.IsValid() {
			return errors.New("killswitch: invalid server address")
		}
	}
	for _, p := range o.AllowRanges {
		if !p.IsValid() {
			return errors.New("killswitch: invalid address range")
		}
	}
	for _, app := range o.Apps {
		if app == "" {
			return errors.New("killswitch: empty program path")
		}
	}
	return nil
}

var (
	lan4 = []netip.Prefix{
		netip.MustParsePrefix("10.0.0.0/8"),
		netip.MustParsePrefix("172.16.0.0/12"),
		netip.MustParsePrefix("192.168.0.0/16"),
		netip.MustParsePrefix("169.254.0.0/16"),
		netip.MustParsePrefix("224.0.0.0/4"),
		netip.MustParsePrefix("255.255.255.255/32"),
	}
	lan6 = []netip.Prefix{
		netip.MustParsePrefix("fe80::/10"),
		netip.MustParsePrefix("fc00::/7"),
		netip.MustParsePrefix("ff00::/8"),
	}
)

// Build returns the rules for opts, deterministically. The rule set is the
// same shape for both directions and both IP versions.
func Build(o Options) ([]Rule, error) {
	if err := o.Validate(); err != nil {
		return nil, err
	}
	var rules []Rule
	for _, fam := range []Family{IPv4, IPv6} {
		for _, dir := range []Direction{Outbound, Inbound} {
			rules = append(rules, buildFor(o, fam, dir)...)
		}
	}
	return rules, nil
}

func buildFor(o Options, fam Family, dir Direction) []Rule {
	name := func(what string) string { return fmt.Sprintf("Wardkeep kill switch: %s (IPv%d %s)", what, fam, dir) }
	mk := func(what string, action Action, weight uint64, conds ...Condition) Rule {
		return Rule{Name: name(what), Direction: dir, Family: fam, Action: action, Weight: weight, Conditions: conds}
	}
	var rules []Rule

	rules = append(rules, mk("block everything else", Block, weightBlock))
	rules = append(rules, mk("loopback", Permit, weightLoopback, Condition{Field: Loopback}))
	if o.TunLUID != 0 {
		rules = append(rules, mk("tunnel adapter", Permit, weightTunnel,
			Condition{Field: LocalInterface, Values: []any{o.TunLUID}}))
	}
	if len(o.Apps) > 0 {
		apps := make([]any, len(o.Apps))
		for i, a := range o.Apps {
			apps[i] = a
		}
		rules = append(rules, mk("programs", Permit, weightApps, Condition{Field: Application, Values: apps}))
	}
	var servers []any
	for _, a := range o.ServerAddrs {
		a = a.Unmap()
		if (fam == IPv4) == a.Is4() {
			servers = append(servers, netip.PrefixFrom(a, a.BitLen()))
		}
	}
	for _, chunk := range chunks(servers, rangesPerRule) {
		rules = append(rules, mk("VPN servers", Permit, weightServers, Condition{Field: RemoteAddress, Values: chunk}))
	}

	// Address assignment and neighbour discovery must keep working or the
	// network adapter itself loses its address.
	switch fam {
	case IPv4:
		rules = append(rules, mk("DHCP", Permit, weightProtocols,
			Condition{Field: Protocol, Values: []any{ProtoUDP}},
			Condition{Field: LocalPort, Values: []any{uint16(68)}},
			Condition{Field: RemotePort, Values: []any{uint16(67)}}))
	case IPv6:
		rules = append(rules, mk("DHCPv6", Permit, weightProtocols,
			Condition{Field: Protocol, Values: []any{ProtoUDP}},
			Condition{Field: LocalPort, Values: []any{uint16(546)}},
			Condition{Field: RemotePort, Values: []any{uint16(547)}}))
		// Router/neighbour solicitation and advertisement, redirect (RFC 4861).
		rules = append(rules, mk("neighbour discovery", Permit, weightProtocols,
			Condition{Field: Protocol, Values: []any{ProtoICMPv6}},
			Condition{Field: LocalPort, Values: []any{uint16(133), uint16(134), uint16(135), uint16(136), uint16(137)}}))
	}

	if o.AllowLAN {
		local := lan4
		if fam == IPv6 {
			local = lan6
		}
		rules = append(rules, mk("local network", Permit, weightLAN, Condition{Field: RemoteAddress, Values: prefixValues(local)}))
	}
	var extra []any
	for _, p := range o.AllowRanges {
		p = netip.PrefixFrom(p.Addr().Unmap(), p.Bits()).Masked()
		if (fam == IPv4) == p.Addr().Is4() {
			extra = append(extra, p)
		}
	}
	for _, chunk := range chunks(extra, rangesPerRule) {
		rules = append(rules, mk("bypass ranges", Permit, weightRanges, Condition{Field: RemoteAddress, Values: chunk}))
	}
	return rules
}

func prefixValues(ps []netip.Prefix) []any {
	out := make([]any, len(ps))
	for i, p := range ps {
		out[i] = p
	}
	return out
}

func chunks(vals []any, n int) [][]any {
	var out [][]any
	for chunk := range slices.Chunk(vals, n) {
		out = append(out, chunk)
	}
	return out
}
