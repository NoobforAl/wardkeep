package singbox

import (
	"errors"
	"fmt"
	"net"
	"net/netip"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/dnscrypt"
)

// IsDNSStamp reports whether a resolver setting is a DNS stamp ("sdns://...").
func IsDNSStamp(raw string) bool {
	return strings.HasPrefix(strings.TrimSpace(raw), dnscrypt.StampPrefix)
}

// DNSNeedsForwarder reports whether the resolver setting is a DNSCrypt stamp,
// which sing-box cannot speak: the engine then runs a local forwarder
// (core/dnscrypt) and Options.DNSForwarder names its address.
func DNSNeedsForwarder(raw string) bool {
	if !IsDNSStamp(raw) {
		return false
	}
	st, err := dnscrypt.ParseStamp(raw)
	return err == nil && st.Kind == dnscrypt.KindDNSCrypt
}

// CheckDNS says whether a resolver setting can be used, with an error that can
// be shown to people. It accepts what dnsServer accepts, plus stamps.
func CheckDNS(raw string) error {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	if IsDNSStamp(raw) {
		_, _, err := stampServer(raw, "127.0.0.1:1")
		return err
	}
	_, err := dnsServer(raw)
	return err
}

// CheckDNSRelay says whether the relay setting of Anonymized DNSCrypt is usable.
func CheckDNSRelay(raw string) error {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	_, err := dnscrypt.ParseRelayStamp(raw)
	return err
}

// DNSDescription is a short name of the resolver for the UI, e.g. "DNSCrypt · quad9.net".
func DNSDescription(raw, relay string) string {
	if strings.TrimSpace(raw) == "" {
		return ""
	}
	if !IsDNSStamp(raw) {
		return raw
	}
	st, err := dnscrypt.ParseStamp(raw)
	if err != nil {
		return raw
	}
	s := st.Kind.String() + " · " + st.Name()
	if st.Kind == dnscrypt.KindDNSCrypt && strings.TrimSpace(relay) != "" {
		s += " (anonymized)"
	}
	return s
}

// stampServer converts a stamp into a sing-box DNS server and returns the IP
// addresses the stamp names. A DNSCrypt stamp becomes a plain UDP server on the
// local forwarder (forwarder is "127.0.0.1:port"); the others are reached
// through the tunnel, by the IP in the stamp when there is one, so the name of
// the resolver is not looked up outside the VPN.
func stampServer(raw, forwarder string) (obj, []netip.Addr, error) {
	st, err := dnscrypt.ParseStamp(raw)
	if err != nil {
		return nil, nil, err
	}
	switch st.Kind {
	case dnscrypt.KindRelay:
		return nil, nil, errors.New("this stamp is a relay, not a resolver; put it in the relay setting")
	case dnscrypt.KindDNSCrypt:
		host, port, err := net.SplitHostPort(forwarder)
		if forwarder == "" || err != nil {
			return nil, nil, errors.New("DNSCrypt needs the local forwarder, which the engine starts")
		}
		p, _ := strconv.Atoi(port)
		return obj{"type": "udp", "server": host, "server_port": p}, st.IPs(), nil
	}

	server := obj{"server_port": st.Port}
	addr := st.HostAddr() // the stamp's IP when it has one, else the host name
	host, _, err := net.SplitHostPort(addr)
	if err != nil || host == "" {
		return nil, nil, fmt.Errorf("the stamp has no usable address")
	}
	server["server"] = host
	if len(st.IPs()) == 0 && len(st.Bootstrap) > 0 {
		server["server"] = st.Bootstrap[0]
	}
	server["detour"] = TagSelect
	switch st.Kind {
	case dnscrypt.KindPlain:
		server["type"] = "udp"
		return server, st.IPs(), nil
	case dnscrypt.KindDoH:
		server["type"] = "https"
		if st.Path != "" && st.Path != "/dns-query" {
			server["path"] = st.Path
		}
	case dnscrypt.KindDoT:
		server["type"] = "tls"
	case dnscrypt.KindDoQ:
		server["type"] = "quic"
	}
	// Connecting to an IP: the certificate is still checked against the host name.
	if _, err := netip.ParseAddr(fmt.Sprint(server["server"])); err == nil && st.Host != "" {
		server["tls"] = obj{"enabled": true, "server_name": st.Host}
	}
	return server, st.IPs(), nil
}

// remoteDNSServer makes the "remote" DNS server of a config from Options.DNS
// (a resolver URL or a DNS stamp), and lists, as CIDRs, the resolver and relay
// addresses that must only be reached through the VPN.
func remoteDNSServer(opts Options) (obj, []string, error) {
	if !IsDNSStamp(opts.DNS) {
		server, err := dnsServer(opts.DNS)
		if err != nil {
			return nil, nil, err
		}
		server["detour"] = TagSelect
		return server, nil, nil
	}
	server, ips, err := stampServer(strings.TrimSpace(opts.DNS), opts.DNSForwarder)
	if err != nil {
		return nil, nil, fmt.Errorf("DNS: %w", err)
	}
	if strings.TrimSpace(opts.DNSRelay) != "" {
		relay, err := dnscrypt.ParseRelayStamp(opts.DNSRelay)
		if err != nil {
			return nil, nil, fmt.Errorf("DNS relay: %w", err)
		}
		ips = append(ips, relay.IPs()...)
	}
	var cidrs []string
	seen := map[netip.Addr]bool{}
	for _, ip := range ips {
		if ip = ip.Unmap(); !seen[ip] {
			seen[ip] = true
			cidrs = append(cidrs, netip.PrefixFrom(ip, ip.BitLen()).String())
		}
	}
	return server, cidrs, nil
}

// torDNSOK reports whether a resolver setting works through a Tor exit, which
// allows HTTPS (DoH) and TCP to the ports its policy opens, but not DNS over
// TLS or plain DNS. A DNSCrypt stamp is kept: the forwarder uses TCP only.
func torDNSOK(raw string) bool {
	if strings.HasPrefix(raw, "https://") {
		return true
	}
	if !IsDNSStamp(raw) {
		return false
	}
	st, err := dnscrypt.ParseStamp(raw)
	return err == nil && (st.Kind == dnscrypt.KindDoH || st.Kind == dnscrypt.KindDNSCrypt)
}
