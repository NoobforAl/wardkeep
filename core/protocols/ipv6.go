package protocols

import (
	"fmt"
	"net/netip"
)

// IPv6 inside the tunnels. A server with Env.IPv6 gives each user a second
// address in every tunnel that can carry one: WireGuard, AmneziaWG, OpenVPN
// and IKEv2/IPsec (SSTP cannot). The addresses are unique local (fd00::/8), so
// the server's NAT66 has to hide them like it hides the IPv4 ones, and they
// are derived from the IPv4 address the user already has, so nothing is stored
// and a user keeps both across a restart.
const (
	WGPool6          = "fd30:0:0:1::/64"
	wgServerAddress6 = "fd30:0:0:1::1/64"
	AWGPool6         = "fd31:0:0:1::/64"
	awgServerAddr6   = "fd31:0:0:1::1/64"
	// IKEv2Pool6 is the pool the IKEv2 server hands out v6 addresses from.
	IKEv2Pool6 = "fd10:10:10::/64"

	openvpnUDPAddress6 = "fd18:0:0:1::1/64"
	openvpnTCPAddress6 = "fd19:0:0:1::1/64"
)

// OpenVPNPools6 are the IPv6 pools of OpenVPN over UDP and over TCP.
var OpenVPNPools6 = []string{"fd18:0:0:1::/64", "fd19:0:0:1::/64"}

// AWGServerAddress6 is the server's IPv6 address in the AmneziaWG tunnel.
func AWGServerAddress6() string { return awgServerAddr6 }

// WGAddress6 is the IPv6 address of a user's WireGuard tunnel address
// (10.30.a.b/32 -> fd30:0:0:1::ab/128, the last two octets as one 16-bit number).
func WGAddress6(wgAddress string) (string, error) { return address6(wgAddress, WGPool6) }

// AWGAddress6 is the IPv6 address of a user's AmneziaWG tunnel address
// (the same user, fd31:0:0:1::ab/128).
func AWGAddress6(wgAddress string) (string, error) { return address6(wgAddress, AWGPool6) }

func address6(wgAddress, pool string) (string, error) {
	prefix, err := netip.ParsePrefix(wgAddress)
	if err != nil || !prefix.Addr().Is4() {
		return "", fmt.Errorf("%q is not an IPv4 tunnel address", wgAddress)
	}
	v4 := prefix.Addr().As4()
	b := netip.MustParsePrefix(pool).Addr().As16()
	b[14], b[15] = v4[2], v4[3]
	return netip.PrefixFrom(netip.AddrFrom16(b), 128).String(), nil
}
