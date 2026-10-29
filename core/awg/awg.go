// Package awg runs AmneziaWG (WireGuard with DPI-resistant junk/obfuscation
// parameters) on a TUN file descriptor provided by the OS (Android VpnService).
// sing-box has no AmneziaWG support, so this is a separate engine.
package awg

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/amnezia-vpn/amneziawg-go/conn"
	"github.com/amnezia-vpn/amneziawg-go/device"

	"github.com/NoobforAl/omnitun/core/profile"
)

// deviceKeys are the AmneziaWG device parameters amneziawg-go accepts, in UAPI
// order: junk packets before the handshake (jc, jmin, jmax), random prefixes on
// the handshake's two packets (s1, s2), on the cookie packet (s3) and on data
// packets (s4), and the four message-type headers (h1-h4), which in AmneziaWG
// 2.0 are ranges ("100-200") a random value is drawn from for every packet.
var deviceKeys = []string{"jc", "jmin", "jmax", "s1", "s2", "s3", "s4", "h1", "h2", "h3", "h4"}

// headerKeys are the deviceKeys that may be a range.
var headerKeys = []string{"h1", "h2", "h3", "h4"}

// chainKeys are the signature packets (i1-i5), sent before the handshake to
// look like another protocol. Their values are tag chains such as
// "<b 0xc0ff><r 16><t>", passed on verbatim.
var chainKeys = []string{"i1", "i2", "i3", "i4", "i5"}

// retiredKeys are names of AmneziaWG 1.5 that version 2.0 no longer has: the
// time between signature packets (itime) and the "controlled junk" chains
// (j1-j3). Files and links made for 1.5 may still carry them; they are
// left out of the device configuration instead of making the connection fail.
var retiredKeys = []string{"itime", "j1", "j2", "j3"}

// ErrUnsupported is returned for parameters this AmneziaWG version can't apply.
var ErrUnsupported = errors.New("unsupported AmneziaWG parameter")

func keyHex(b64 string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(b64))
	if err != nil || len(raw) != 32 {
		return "", fmt.Errorf("invalid key %q", b64)
	}
	return hex.EncodeToString(raw), nil
}

// UAPI builds the device configuration in WireGuard's UAPI text format.
func UAPI(p *profile.Profile, endpoint netip.AddrPort) (string, error) {
	wg := p.WireGuard
	if wg == nil {
		return "", errors.New("not a WireGuard/AmneziaWG profile")
	}
	priv, err := keyHex(wg.PrivateKey)
	if err != nil {
		return "", fmt.Errorf("private key: %w", err)
	}
	pub, err := keyHex(wg.PeerPublicKey)
	if err != nil {
		return "", fmt.Errorf("peer public key: %w", err)
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "private_key=%s\n", priv)
	if err := CheckParams(wg.Amnezia); err != nil {
		return "", err
	}
	for _, k := range deviceKeys {
		if v, ok := wg.Amnezia[k]; ok {
			fmt.Fprintf(&sb, "%s=%s\n", k, strings.TrimSpace(v))
		}
	}
	for _, k := range chainKeys {
		if v, ok := wg.Amnezia[k]; ok && strings.TrimSpace(v) != "" {
			if strings.ContainsAny(v, "\r\n") {
				return "", fmt.Errorf("invalid %s: line break", k)
			}
			fmt.Fprintf(&sb, "%s=%s\n", k, strings.TrimSpace(v))
		}
	}
	sb.WriteString("replace_peers=true\n")
	fmt.Fprintf(&sb, "public_key=%s\n", pub)
	if wg.PreSharedKey != "" {
		psk, err := keyHex(wg.PreSharedKey)
		if err != nil {
			return "", fmt.Errorf("preshared key: %w", err)
		}
		fmt.Fprintf(&sb, "preshared_key=%s\n", psk)
	}
	fmt.Fprintf(&sb, "endpoint=%s\n", endpoint)
	keepalive := wg.Keepalive
	if keepalive == 0 {
		keepalive = 25 // keeps NAT mappings alive on mobile networks
	}
	fmt.Fprintf(&sb, "persistent_keepalive_interval=%d\n", keepalive)
	sb.WriteString("replace_allowed_ips=true\n")
	allowed := wg.AllowedIPs
	if len(allowed) == 0 {
		allowed = []string{"0.0.0.0/0", "::/0"}
	}
	for _, a := range allowed {
		fmt.Fprintf(&sb, "allowed_ip=%s\n", strings.TrimSpace(a))
	}
	return sb.String(), nil
}

func isDeviceKey(k string) bool { return slices.Contains(deviceKeys, k) }

// uintRange reads "n" or "lo-hi" (decimal, lo <= hi).
func uintRange(v string) (lo, hi uint64, err error) {
	a, b, isRange := strings.Cut(strings.TrimSpace(v), "-")
	if lo, err = strconv.ParseUint(strings.TrimSpace(a), 10, 32); err != nil {
		return 0, 0, errors.New("not a number or a range such as 100-200")
	}
	hi = lo
	if isRange {
		if hi, err = strconv.ParseUint(strings.TrimSpace(b), 10, 32); err != nil {
			return 0, 0, errors.New("not a number or a range such as 100-200")
		}
		if hi < lo {
			return 0, 0, errors.New("the range ends before it starts")
		}
	}
	return lo, hi, nil
}

// CheckParams validates AmneziaWG's parameters (the keys of a profile's
// Amnezia map) before they reach the device, so a mistake is reported in words
// instead of as a device error. It knows AmneziaWG 1.x (plain numbers), 1.5
// (signature packets) and 2.0 (s3, s4 and header ranges); a header that is a
// number is a range of one.
func CheckParams(params map[string]string) error {
	for k, value := range params {
		switch {
		case slices.Contains(chainKeys, k):
			if strings.ContainsAny(value, "\r\n") {
				return fmt.Errorf("invalid %s: line break", k)
			}
		case slices.Contains(retiredKeys, k):
			// ignored, see retiredKeys
		case slices.Contains(headerKeys, k):
			if _, _, err := uintRange(value); err != nil {
				return fmt.Errorf("invalid %s=%q: %w", k, value, err)
			}
		case isDeviceKey(k):
			if _, err := strconv.ParseUint(strings.TrimSpace(value), 10, 16); err != nil {
				return fmt.Errorf("invalid %s=%q: not a number from 0 to 65535", k, value)
			}
		default:
			return fmt.Errorf("%w %q", ErrUnsupported, k)
		}
	}
	if err := checkJunk(params); err != nil {
		return err
	}
	// The four headers name four kinds of packet: a value shared by two of them could not be told apart.
	type span struct {
		key    string
		lo, hi uint64
	}
	var spans []span
	for _, k := range headerKeys {
		if v, ok := params[k]; ok {
			lo, hi, _ := uintRange(v)
			spans = append(spans, span{k, lo, hi})
		}
	}
	for i := range spans {
		for j := i + 1; j < len(spans); j++ {
			if spans[i].lo <= spans[j].hi && spans[j].lo <= spans[i].hi {
				return fmt.Errorf("%s and %s overlap: the four headers must not share a value", spans[i].key, spans[j].key)
			}
		}
	}
	if v1, ok1 := params["s1"]; ok1 {
		if v2, ok2 := params["s2"]; ok2 {
			a, _ := strconv.ParseUint(strings.TrimSpace(v1), 10, 16)
			c, _ := strconv.ParseUint(strings.TrimSpace(v2), 10, 16)
			if a+56 == c {
				return errors.New("s1 + 56 must not equal s2: the handshake's two packets would have the same length")
			}
		}
	}
	return nil
}

// checkJunk wants jmin <= jmax when both are given.
func checkJunk(params map[string]string) error {
	lo, hasLo := params["jmin"]
	hi, hasHi := params["jmax"]
	if hasLo && hasHi {
		a, _ := strconv.ParseUint(strings.TrimSpace(lo), 10, 16)
		b, _ := strconv.ParseUint(strings.TrimSpace(hi), 10, 16)
		if a > b {
			return errors.New("jmin must not be larger than jmax")
		}
	}
	return nil
}

// Generation names the AmneziaWG version a profile's parameters need: "2.0"
// (s3, s4 or a header range), "1.5" (signature packets), else "1.x".
func Generation(params map[string]string) string {
	for _, k := range []string{"s3", "s4"} {
		if _, ok := params[k]; ok {
			return "2.0"
		}
	}
	for _, k := range headerKeys {
		if v, ok := params[k]; ok && strings.Contains(v, "-") {
			return "2.0"
		}
	}
	for _, k := range chainKeys {
		if v, ok := params[k]; ok && strings.TrimSpace(v) != "" {
			return "1.5"
		}
	}
	return "1.x"
}

// ResolveEndpoint returns the peer address; host names are resolved with the
// system resolver (before the tunnel exists).
func ResolveEndpoint(ctx context.Context, prof *profile.Profile) (netip.AddrPort, error) {
	if prof.Port < 1 || prof.Port > 65535 {
		return netip.AddrPort{}, fmt.Errorf("invalid port %d", prof.Port)
	}
	port := uint16(prof.Port)
	if addr, err := netip.ParseAddr(prof.Server); err == nil {
		return netip.AddrPortFrom(addr.Unmap(), port), nil
	}
	addrs, err := net.DefaultResolver.LookupNetIP(ctx, "ip", prof.Server)
	if err != nil || len(addrs) == 0 {
		return netip.AddrPort{}, fmt.Errorf("resolve %s: %w", prof.Server, err)
	}
	// Prefer IPv4: many mobile networks have broken IPv6.
	for _, a := range addrs {
		if a.Unmap().Is4() {
			return netip.AddrPortFrom(a.Unmap(), port), nil
		}
	}
	return netip.AddrPortFrom(addrs[0], port), nil
}

// Tunnel is a running AmneziaWG device.
type Tunnel struct {
	dev *device.Device
}

// Start creates the device on tunFD (which it duplicates; the caller keeps
// its own descriptor), applies the profile and brings it up. protect is
// called with the UDP socket descriptors so they bypass the VPN.
func Start(p *profile.Profile, endpoint netip.AddrPort, tunFD int, protect func(fd int) error, logf func(string, ...any)) (*Tunnel, error) {
	uapi, err := UAPI(p, endpoint)
	if err != nil {
		return nil, err
	}
	tunDev, err := createTUN(tunFD)
	if err != nil {
		return nil, fmt.Errorf("open tun: %w", err)
	}
	logger := &device.Logger{
		Verbosef: func(string, ...any) {},
		Errorf: func(format string, args ...any) {
			if logf != nil {
				logf("awg: "+format, args...)
			}
		},
	}
	bind := conn.NewDefaultBind()
	dev := device.NewDevice(tunDev, bind, logger)
	if err := dev.IpcSet(uapi); err != nil {
		dev.Close()
		return nil, fmt.Errorf("configure: %w", err)
	}
	if err := dev.Up(); err != nil {
		dev.Close()
		return nil, fmt.Errorf("bring up: %w", err)
	}
	if err := protectBind(bind, protect); err != nil {
		dev.Close()
		return nil, fmt.Errorf("protect socket: %w", err)
	}
	return &Tunnel{dev: dev}, nil
}

// Stats is a snapshot of the peer.
type Stats struct {
	RxBytes, TxBytes int64
	LastHandshake    time.Time
}

// Stats reads counters from the device.
func (t *Tunnel) Stats() Stats {
	raw, err := t.dev.IpcGet()
	if err != nil {
		return Stats{}
	}
	return parseStats(raw)
}

func parseStats(raw string) Stats {
	var stats Stats
	var sec, nsec int64
	for line := range strings.SplitSeq(raw, "\n") {
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		n, _ := strconv.ParseInt(v, 10, 64)
		switch k {
		case "rx_bytes":
			stats.RxBytes += n
		case "tx_bytes":
			stats.TxBytes += n
		case "last_handshake_time_sec":
			sec = n
		case "last_handshake_time_nsec":
			nsec = n
		}
	}
	if sec > 0 {
		stats.LastHandshake = time.Unix(sec, nsec)
	}
	return stats
}

// Close shuts the device down and closes its TUN.
func (t *Tunnel) Close() { t.dev.Close() }
