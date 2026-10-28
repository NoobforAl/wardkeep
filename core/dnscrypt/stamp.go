// Package dnscrypt resolves DNS names with DNSCrypt (and Anonymized DNSCrypt
// through a relay) and offers the answers to the rest of the app through a
// forwarder on the loopback interface.
//
// Resolver addresses are DNS stamps ("sdns://..."), a compact string holding
// the protocol, address, port, provider name and public key; see
// https://dnscrypt.info/stamps-specifications. This file reads and writes them.
// The library github.com/ameshkov/dnsstamps is not used for parsing because it
// has no relay stamps and mis-sets the default port of DoT and DoQ; the tests
// compare the two on every type the library knows.
package dnscrypt

import (
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"strconv"
	"strings"
)

// StampPrefix starts every DNS stamp.
const StampPrefix = "sdns://"

// Kind is the protocol a stamp names.
type Kind uint8

// Stamp kinds, numbered as in the stamp format (a relay is 0x81).
const (
	KindPlain    Kind = 0x00
	KindDNSCrypt Kind = 0x01
	KindDoH      Kind = 0x02
	KindDoT      Kind = 0x03
	KindDoQ      Kind = 0x04
	KindRelay    Kind = 0x81
)

func (k Kind) String() string {
	switch k {
	case KindPlain:
		return "Plain"
	case KindDNSCrypt:
		return "DNSCrypt"
	case KindDoH:
		return "DoH"
	case KindDoT:
		return "DoT"
	case KindDoQ:
		return "DoQ"
	case KindRelay:
		return "relay"
	}
	return fmt.Sprintf("kind 0x%02x", uint8(k))
}

// Props are the informal properties a resolver declares about itself.
type Props uint64

// Resolver properties.
const (
	PropDNSSEC   Props = 1 << 0 // validates DNSSEC
	PropNoLog    Props = 1 << 1 // keeps no logs
	PropNoFilter Props = 1 << 2 // blocks nothing on purpose
)

// Stamp is a parsed DNS stamp.
type Stamp struct {
	Kind  Kind
	Props Props
	// Addr is the server address as written, "host", "ip", "ip:port" or
	// "[v6]:port"; may be empty for DoH, DoT and DoQ (the host name is used).
	Addr string
	// Host is the TLS name of a DoH, DoT or DoQ server, without port.
	Host string
	// Port is the effective port: the one written, or the protocol's default.
	Port int
	// Path is the HTTP path of a DoH server.
	Path string
	// PublicKey is the DNSCrypt provider's Ed25519 key (32 bytes).
	PublicKey []byte
	// ProviderName is the DNSCrypt provider name, e.g. "2.dnscrypt-cert.example".
	ProviderName string
	// Hashes pin the certificate chain of DoH, DoT and DoQ servers.
	Hashes [][]byte
	// Bootstrap lists IP addresses of a DoH, DoT or DoQ server host.
	Bootstrap []string
}

// StampError says why a stamp could not be used. Its text is shown to people.
type StampError struct{ Msg string }

func (e *StampError) Error() string { return e.Msg }

func badStamp(format string, args ...any) error {
	return &StampError{Msg: fmt.Sprintf(format, args...)}
}

func defaultPort(k Kind) int {
	switch k {
	case KindPlain:
		return 53
	case KindDoT, KindDoQ:
		return 853
	}
	return 443
}

// stampReader walks the bytes of a stamp.
type stampReader struct {
	b   []byte
	pos int
	err error
}

func (r *stampReader) fail() {
	if r.err == nil {
		r.err = badStamp("the stamp is cut short")
	}
}

func (r *stampReader) u8() byte {
	if r.pos >= len(r.b) {
		r.fail()
		return 0
	}
	v := r.b[r.pos]
	r.pos++
	return v
}

func (r *stampReader) take(n int) []byte {
	if r.pos+n > len(r.b) {
		r.fail()
		return nil
	}
	v := r.b[r.pos : r.pos+n]
	r.pos += n
	return v
}

// lp reads a length-prefixed string.
func (r *stampReader) lp() []byte { return r.take(int(r.u8())) }

// vlp reads a variable-length set: every item but the last has its top bit
// set in the length byte. An empty item is skipped.
func (r *stampReader) vlp() [][]byte {
	var out [][]byte
	for r.err == nil {
		l := r.u8()
		item := r.take(int(l & 0x7f))
		if len(item) > 0 {
			out = append(out, item)
		}
		if l&0x80 == 0 {
			break
		}
	}
	return out
}

func (r *stampReader) atEnd() bool { return r.pos >= len(r.b) }

// ParseStamp reads a DNS stamp of any kind this package knows.
func ParseStamp(s string) (Stamp, error) {
	s = strings.TrimSpace(s)
	if !strings.HasPrefix(s, StampPrefix) {
		return Stamp{}, badStamp("a DNS stamp starts with %s", StampPrefix)
	}
	raw, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(s[len(StampPrefix):], "="))
	if err != nil {
		return Stamp{}, badStamp("the stamp is not valid base64")
	}
	if len(raw) == 0 {
		return Stamp{}, badStamp("the stamp is empty")
	}
	reader := &stampReader{b: raw, pos: 1}
	st := Stamp{Kind: Kind(raw[0])}
	switch st.Kind {
	case KindPlain, KindDNSCrypt, KindDoH, KindDoT, KindDoQ:
		var props [8]byte
		copy(props[:], reader.take(8))
		st.Props = Props(binary.LittleEndian.Uint64(props[:]))
		st.Addr = string(reader.lp())
	case KindRelay:
		st.Addr = string(reader.lp())
	default:
		return Stamp{}, badStamp("this stamp type (0x%02x) is not supported", raw[0])
	}
	switch st.Kind {
	case KindDNSCrypt:
		st.PublicKey = append([]byte(nil), reader.lp()...)
		st.ProviderName = string(reader.lp())
	case KindDoH:
		st.Hashes = reader.vlp()
		st.Host = string(reader.lp())
		st.Path = string(reader.lp())
		if !reader.atEnd() {
			st.Bootstrap = ipStrings(reader.vlp())
		}
	case KindDoT, KindDoQ:
		st.Hashes = reader.vlp()
		st.Host = string(reader.lp())
		if !reader.atEnd() {
			st.Bootstrap = ipStrings(reader.vlp())
		}
	}
	if reader.err != nil {
		return Stamp{}, reader.err
	}
	if !reader.atEnd() {
		return Stamp{}, badStamp("the stamp has extra data at its end")
	}
	return st, st.resolve()
}

func ipStrings(in [][]byte) []string {
	out := make([]string, 0, len(in))
	for _, b := range in {
		out = append(out, string(b))
	}
	return out
}

// resolve fills Host and Port, and checks the fields the kind needs.
func (st *Stamp) resolve() error {
	switch st.Kind {
	case KindDNSCrypt:
		if len(st.PublicKey) != 32 {
			return badStamp("the DNSCrypt public key must be 32 bytes, this one has %d", len(st.PublicKey))
		}
		if st.ProviderName == "" {
			return badStamp("the DNSCrypt provider name is missing")
		}
		if st.Addr == "" {
			return badStamp("the DNSCrypt server address is missing")
		}
	case KindDoH, KindDoT, KindDoQ:
		if st.Host == "" && st.Addr == "" {
			return badStamp("the %s stamp has neither a host name nor an address", st.Kind)
		}
	case KindPlain, KindRelay:
		if st.Addr == "" {
			return badStamp("the %s stamp has no address", st.Kind)
		}
	}
	// The port comes from the host name when the stamp has one, otherwise from the address.
	port, hasPort := 0, false
	switch st.Kind {
	case KindDoH, KindDoT, KindDoQ:
		if st.Host != "" {
			h, p, ok := splitHostPort(st.Host)
			if !ok {
				return badStamp("the host name %q is not valid", st.Host)
			}
			st.Host, port, hasPort = h, p, p != 0
		}
		if !hasPort && st.Addr != "" {
			if _, p, ok := splitHostPort(st.Addr); ok && p != 0 {
				port, hasPort = p, true
			}
		}
	default:
		_, p, ok := splitHostPort(st.Addr)
		if !ok {
			return badStamp("the address %q is not valid", st.Addr)
		}
		port, hasPort = p, p != 0
	}
	if !hasPort {
		port = defaultPort(st.Kind)
	}
	st.Port = port
	return nil
}

// splitHostPort splits "host", "host:port", "ip", "[v6]" and "[v6]:port"; port
// is 0 when absent.
func splitHostPort(addr string) (host string, port int, ok bool) {
	if addr == "" {
		return "", 0, true
	}
	if strings.HasPrefix(addr, "[") {
		end := strings.Index(addr, "]")
		if end < 0 {
			return "", 0, false
		}
		host = addr[1:end]
		rest := addr[end+1:]
		if rest == "" {
			return host, 0, true
		}
		if !strings.HasPrefix(rest, ":") {
			return "", 0, false
		}
		p, err := strconv.Atoi(rest[1:])
		if err != nil || p <= 0 || p > 65535 {
			return "", 0, false
		}
		return host, p, true
	}
	if _, err := netip.ParseAddr(addr); err == nil {
		return addr, 0, true // a bare IP (v4, or v6 without brackets)
	}
	if i := strings.LastIndex(addr, ":"); i >= 0 {
		if strings.Contains(addr[:i], ":") {
			return "", 0, false
		}
		p, err := strconv.Atoi(addr[i+1:])
		if err != nil || p <= 0 || p > 65535 {
			return "", 0, false
		}
		return addr[:i], p, true
	}
	return addr, 0, true
}

// HostAddr returns the address to connect to as "host:port" ("[v6]:port" for
// IPv6): the address in the stamp, or for DoH, DoT and DoQ the host name.
func (st Stamp) HostAddr() string {
	host := st.Host
	if st.Addr != "" {
		if h, _, ok := splitHostPort(st.Addr); ok && h != "" {
			host = h
		}
	}
	if host == "" {
		return ""
	}
	return net.JoinHostPort(host, strconv.Itoa(st.Port))
}

// IPs returns the IP addresses written in the stamp (the address, and the
// bootstrap list of a DoH, DoT or DoQ server).
func (st Stamp) IPs() []netip.Addr {
	var out []netip.Addr
	add := func(s string) {
		h, _, ok := splitHostPort(s)
		if !ok {
			return
		}
		if a, err := netip.ParseAddr(h); err == nil {
			out = append(out, a)
		}
	}
	add(st.Addr)
	for _, b := range st.Bootstrap {
		add(b)
	}
	return out
}

// Name is a short name for people: the provider name without its DNSCrypt
// prefix for DNSCrypt, the host name for the others.
func (st Stamp) Name() string {
	switch st.Kind {
	case KindDNSCrypt:
		return strings.TrimPrefix(st.ProviderName, "2.dnscrypt-cert.")
	case KindRelay, KindPlain:
		return st.Addr
	}
	if st.Host != "" {
		return st.Host
	}
	return st.Addr
}

// String encodes the stamp.
func (st Stamp) String() string {
	var out []byte
	out = append(out, byte(st.Kind))
	lp := func(s []byte) {
		out = append(out, byte(len(s)))
		out = append(out, s...)
	}
	vlp := func(items [][]byte) {
		if len(items) == 0 {
			out = append(out, 0)
			return
		}
		for i, it := range items {
			l := byte(len(it))
			if i < len(items)-1 {
				l |= 0x80
			}
			out = append(out, l)
			out = append(out, it...)
		}
	}
	if st.Kind != KindRelay {
		var p [8]byte
		binary.LittleEndian.PutUint64(p[:], uint64(st.Props))
		out = append(out, p[:]...)
	}
	lp([]byte(st.Addr))
	switch st.Kind {
	case KindDNSCrypt:
		lp(st.PublicKey)
		lp([]byte(st.ProviderName))
	case KindDoH, KindDoT, KindDoQ:
		vlp(st.Hashes)
		host := st.Host
		if p := st.Port; p != 0 && p != defaultPort(st.Kind) && !strings.Contains(host, ":") {
			host = net.JoinHostPort(host, strconv.Itoa(p))
		}
		lp([]byte(host))
		if st.Kind == KindDoH {
			lp([]byte(st.Path))
		}
		if len(st.Bootstrap) > 0 {
			var items [][]byte
			for _, s := range st.Bootstrap {
				items = append(items, []byte(s))
			}
			vlp(items)
		}
	}
	return StampPrefix + base64.RawURLEncoding.EncodeToString(out)
}

// ErrNotDNSCrypt is returned where a DNSCrypt stamp is needed.
var ErrNotDNSCrypt = errors.New("not a DNSCrypt stamp")

// ParseDNSCryptStamp reads a stamp and insists it is a DNSCrypt server.
func ParseDNSCryptStamp(s string) (Stamp, error) {
	st, err := ParseStamp(s)
	if err != nil {
		return st, err
	}
	if st.Kind != KindDNSCrypt {
		return st, badStamp("expected a DNSCrypt stamp, this one is %s", st.Kind)
	}
	return st, nil
}

// ParseRelayStamp reads the address of a relay: a relay stamp, or a plain
// "ip:port" address.
func ParseRelayStamp(text string) (Stamp, error) {
	text = strings.TrimSpace(text)
	if !strings.HasPrefix(text, StampPrefix) {
		host, port, ok := splitHostPort(text)
		if !ok || host == "" || !validHostname(host) {
			return Stamp{}, badStamp("a relay is a relay stamp (sdns://...) or an address like 203.0.113.5:443")
		}
		if port == 0 {
			port = 443
		}
		st := Stamp{Kind: KindRelay, Addr: net.JoinHostPort(host, strconv.Itoa(port)), Port: port}
		return st, nil
	}
	st, err := ParseStamp(text)
	if err != nil {
		return st, err
	}
	if st.Kind != KindRelay {
		return st, badStamp("expected a relay stamp, this one is %s", st.Kind)
	}
	return st, nil
}

// validHostname accepts an IP address or a plausible DNS name.
func validHostname(host string) bool {
	if _, err := netip.ParseAddr(host); err == nil {
		return true
	}
	if host == "" || len(host) > 253 {
		return false
	}
	for _, c := range host {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '-', c == '.', c == '_':
		default:
			return false
		}
	}
	return true
}
