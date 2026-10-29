// Package singbox converts profiles into a sing-box configuration.
package singbox

import (
	"errors"
	"fmt"
	"net"
	"net/netip"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/profile"
)

// HelperSocks is where a helper tunnel's local port is, and the SOCKS5 login its far end asks for (both empty: none).
type HelperSocks struct {
	Addr     string
	Username string
	Password string
}

// ErrOtherEngine marks profiles that another engine of the core runs
// (AmneziaWG, a DNS tunnel): they have no sing-box form.
var ErrOtherEngine = errors.New("not run by sing-box")

// Tags of the built-in outbounds.
const (
	TagSelect = "select"
	TagAuto   = "auto"
	TagDirect = "direct"
)

// Mode selects how traffic enters the engine.
type Mode string

const (
	// ModeProxy exposes a local SOCKS5/HTTP port only; no VPN permission needed.
	ModeProxy Mode = "proxy"
	// ModeTUN captures all traffic through a TUN device.
	ModeTUN Mode = "tun"
)

// Options controls config generation.
type Options struct {
	Mode       Mode
	ListenAddr string // proxy listen address, default 127.0.0.1
	ListenPort int    // proxy port, default 2080
	// Selected is the profile ID to use; empty or TagAuto picks the lowest-latency profile.
	Selected string
	LogLevel string
	// TestURL is probed by the auto group, default https://www.gstatic.com/generate_204.
	TestURL string
	// DNS is the remote resolver used through the tunnel, as a URL:
	// https://host/path (DoH), tls://host (DoT), tcp://host, udp://host or a bare IP (UDP).
	// Default https://1.1.1.1/dns-query.
	DNS string
	// DNS may also be a DNS stamp ("sdns://..."): DoH, DoT, DoQ and plain
	// stamps are used as such; a DNSCrypt stamp is served by a local forwarder
	// (core/dnscrypt) that the engine starts, and DNSForwarder is its address
	// ("127.0.0.1:port"). DNSRelay, a relay stamp or "ip:port", makes DNSCrypt
	// anonymized; the engine hands it to the forwarder.
	DNSRelay     string
	DNSForwarder string
	// LocalDNS is the resolver used outside the tunnel (the proxy servers' own
	// names, and bypassed sites), as a resolver URL. Empty uses the operating
	// system's resolver, which phones need the engine to name (see engine.systemDNS).
	LocalDNS string
	// ProxyPrivate also sends local addresses (LocalPrefixes) through the
	// tunnel; by default they bypass it and aren't routed into the VPN.
	ProxyPrivate bool
	// SystemProxy points the OS proxy settings at the local port while
	// running (proxy mode only); sing-box restores them on stop.
	SystemProxy bool

	// MTU of the TUN device (TUN mode); 0 uses DefaultMTU. A smaller value (1280-1500) helps on
	// networks that drop big packets; valid values are MinMTU to MaxMTU.
	MTU int
	// NoIPv6 keeps IPv6 out of the VPN: names are only resolved to IPv4 addresses and a connection
	// to an IPv6 address is refused (not sent around the VPN, which would leak the real address).
	NoIPv6 bool

	// Failover and FailoverInterval are used by the engine, not the config:
	// when a pinned profile stops responding, switch to the next working one.
	// IncludePackages, when set, sends only these Android apps through the
	// VPN; otherwise ExcludePackages bypass it. TUN mode only.
	IncludePackages []string
	ExcludePackages []string

	Failover         bool
	FailoverInterval time.Duration

	// TorSocks is the running Tor client's SOCKS5 address (host:port); Tor
	// profiles are skipped without it.
	TorSocks string

	// Helpers are the local SOCKS5 ports of helper tunnels (a DNS tunnel) by profile ID; a profile of that kind is
	// skipped without its helper.
	Helpers map[string]HelperSocks

	// StateDir is where mesh (Tailscale) profiles keep their device identity, one
	// folder per profile; empty uses a relative folder.
	StateDir string

	// Bypass lists destinations that go around the VPN. With BypassOnly it is
	// the other way round: only they use the VPN and everything else goes direct.
	Bypass     *BypassList
	BypassOnly bool

	// KillSwitch (Windows, TUN mode) blocks every packet that does not use
	// the tunnel while connected; KillSwitchEarly also blocks while connecting.
	// Like Failover it is acted on by the control server (core/killswitch),
	// not by the generated config.
	KillSwitch      bool
	KillSwitchEarly bool
	// TunName names the TUN adapter (Windows). A fixed name lets the kill
	// switch find the adapter and a later run clean up after a crash
	// (core/winsvc); empty leaves the choice to sing-box.
	TunName string
}

// SelfPackage in ExcludePackages stands for this app: the platform replaces it
// with the app's own package so its sockets (Tor, bridge transports) stay off
// the VPN.
const SelfPackage = "@self"

func (o *Options) defaults() {
	if o.Mode == "" {
		o.Mode = ModeProxy
	}
	if o.ListenAddr == "" {
		o.ListenAddr = "127.0.0.1"
	}
	if o.ListenPort == 0 {
		o.ListenPort = 2080
	}
	if o.LogLevel == "" {
		o.LogLevel = "info"
	}
	if o.TestURL == "" {
		o.TestURL = "https://www.gstatic.com/generate_204"
	}
	if o.DNS == "" {
		o.DNS = "https://1.1.1.1/dns-query"
	}
	// Tor exits don't allow DNS over TLS (port 853) or plain DNS, but they do
	// allow HTTPS: resolve through DoH while Tor is the way out.
	if (o.TorSocks != "" || len(o.Helpers) > 0) && !torDNSOK(o.DNS) {
		o.DNS = "https://1.1.1.1/dns-query"
	}
	if o.Selected == "" {
		o.Selected = TagAuto
	}
}

// The TUN device's packet size: DefaultMTU is what the config always used.
const (
	DefaultMTU = 9000
	MinMTU     = 576
	MaxMTU     = 65535
)

// CheckMTU says whether n is a value a TUN device can have (0 means the default).
func CheckMTU(n int) error {
	if n != 0 && (n < MinMTU || n > MaxMTU) {
		return fmt.Errorf("MTU %d is outside %d-%d", n, MinMTU, MaxMTU)
	}
	return nil
}

type obj = map[string]any

// Build returns a sing-box config (as a JSON-ready map) that routes traffic
// through the given profiles. Profiles the engine cannot run are skipped and
// reported in the returned skipped list.
func Build(profiles []*profile.Profile, opts Options) (obj, []error, error) {
	opts.defaults()
	var (
		outbounds []any
		endpoints []any
		tags      []string
		skipped   []error
		meshTags  []string
	)
	for _, prof := range profiles {
		prof.EnsureID()
		var (
			out        obj
			isEndpoint bool
			extras     []obj
			err        error
		)
		if prof.Protocol == profile.Tor {
			out, err = torOutbound(opts.TorSocks, prof.ID)
		} else if prof.Protocol == profile.DNSTT {
			out, err = helperOutbound(opts.Helpers[prof.ID], prof.ID)
		} else if prof.Protocol == profile.Tailscale {
			// A mesh device is online only while its profile is the selected one.
			if prof.ID != opts.Selected {
				continue
			}
			if !meshSupported {
				return nil, skipped, ErrMeshNotBuilt
			}
			var group obj
			out, group = meshProfile(prof, opts.StateDir)
			meshTags = append(meshTags, out["tag"].(string))
			tags = append(tags, prof.ID)
			endpoints = append(endpoints, out)
			outbounds = append(outbounds, group)
			continue
		} else {
			out, isEndpoint, extras, err = convert(prof, prof.ID)
		}
		if err != nil {
			skipped = append(skipped, fmt.Errorf("%s: %w", prof.DisplayName(), err))
			continue
		}
		if isEndpoint {
			endpoints = append(endpoints, out)
		} else {
			outbounds = append(outbounds, out)
		}
		for _, x := range extras {
			outbounds = append(outbounds, x)
		}
		tags = append(tags, prof.ID)
	}
	if len(tags) == 0 {
		return nil, skipped, fmt.Errorf("no usable profiles")
	}
	if opts.Selected != TagAuto && !slices.Contains(tags, opts.Selected) {
		return nil, skipped, fmt.Errorf("selected profile %q is not available", opts.Selected)
	}

	outbounds = append(outbounds,
		obj{
			"type":      "selector",
			"tag":       TagSelect,
			"outbounds": append([]string{TagAuto}, tags...),
			"default":   opts.Selected,
		},
		obj{
			"type":      "urltest",
			"tag":       TagAuto,
			"outbounds": tags,
			"url":       opts.TestURL,
			"interval":  "3m",
			"tolerance": 50,
		},
		obj{"type": "direct", "tag": TagDirect},
	)

	if err := CheckMTU(opts.MTU); err != nil {
		return nil, skipped, err
	}
	var inbounds []any
	switch opts.Mode {
	case ModeProxy:
		mixed := obj{
			"type":        "mixed",
			"tag":         "mixed-in",
			"listen":      opts.ListenAddr,
			"listen_port": opts.ListenPort,
		}
		if opts.SystemProxy {
			mixed["set_system_proxy"] = true
		}
		inbounds = append(inbounds, mixed)
	case ModeTUN:
		tun := obj{
			"type":         "tun",
			"tag":          "tun-in",
			"address":      tunAddresses,
			"mtu":          orInt(opts.MTU, DefaultMTU),
			"auto_route":   true,
			"strict_route": true,
			"stack":        "mixed",
		}
		if opts.TunName != "" {
			tun["interface_name"] = opts.TunName
		}
		// Tor runs as this app, which is kept out of the VPN; the system TCP
		// stack answers through a listener in this app, and those replies
		// would then bypass the tunnel. gVisor handles everything in userspace.
		if opts.TorSocks != "" {
			tun["stack"] = "gvisor"
		}
		// Local networks don't enter the VPN at all (unless ProxyPrivate), nor do
		// the address ranges of the user's bypass list.
		var local []netip.Prefix
		if !opts.ProxyPrivate {
			local = BypassPrefixes(profileKeep(profiles))
		}
		switch {
		case opts.BypassOnly && opts.Bypass.OnlyRanges():
			// Only addresses are listed: nothing else has to enter the tunnel at
			// all, so the rest of the device's traffic costs the VPN nothing. The
			// tunnel's own subnet stays routed, because its DNS server lives there.
			tun["route_address"] = prefixStrings(append(ParsePrefixes(tunAddresses), MergePrefixes(opts.Bypass.CIDRs)...))
			if len(local) > 0 {
				tun["route_exclude_address"] = prefixStrings(local)
			}
		case !opts.BypassOnly && !opts.Bypass.Empty():
			// Listed ranges stay out of the VPN's routes, as many as fit the
			// route budget; the rest is caught by the rules below.
			tun["route_exclude_address"] = prefixStrings(FitExclusions(local, opts.Bypass.CIDRs, RouteBudget))
		case len(local) > 0:
			tun["route_exclude_address"] = prefixStrings(local)
		}
		// Per-app split tunneling (Android): include wins over exclude.
		if len(opts.IncludePackages) > 0 {
			tun["include_package"] = opts.IncludePackages
		} else if len(opts.ExcludePackages) > 0 {
			tun["exclude_package"] = opts.ExcludePackages
		}
		inbounds = append(inbounds, tun)
	default:
		return nil, skipped, fmt.Errorf("unknown mode %q", opts.Mode)
	}

	remoteDNS, resolverIPs, err := remoteDNSServer(opts)
	if err != nil {
		return nil, skipped, err
	}
	remoteDNS["tag"] = "remote"

	// Rules run in order, cheapest first, so most connections are decided
	// before anything costly happens: DNS by port, then address matches (no
	// packet inspection), and only then sniffing for names — and only when a
	// listed name needs it.
	rules := []any{obj{"port": 53, "action": "hijack-dns"}}
	if opts.NoIPv6 {
		// The TUN keeps its IPv6 address so IPv6 traffic is caught here and refused; with no IPv6
		// address it would go out of the real network instead, around the VPN.
		rules = append(rules, obj{"ip_version": 6, "action": "reject"})
	}
	if len(resolverIPs) > 0 {
		// The resolver of a DNS stamp (and the relay) is only ever reached
		// through the VPN, whatever the bypass lists or local ranges say.
		rules = append(rules, obj{"ip_cidr": resolverIPs, "outbound": TagSelect})
	}
	if !opts.ProxyPrivate {
		// Local addresses go direct (proxy mode, and anything that still
		// reaches the TUN); ranges a profile routes on purpose stay proxied.
		rules = append(rules, obj{"ip_cidr": prefixStrings(BypassPrefixes(profileKeep(profiles))), "outbound": TagDirect})
	}
	// The user's list: these go direct, or (BypassOnly) only these use the VPN.
	routeFinal, dnsFinal, dnsRules := TagSelect, "remote", []any(nil)
	if bypass := opts.Bypass.Optimized(); !bypass.Empty() {
		listed, listedDNS := TagDirect, "local"
		if opts.BypassOnly {
			listed, listedDNS = TagSelect, "remote"
			routeFinal, dnsFinal = TagDirect, "local"
		}
		byAddress, byName := bypass.addressRules(), bypass.domainRules()
		for _, r := range byAddress {
			r["outbound"] = listed
			rules = append(rules, obj(r))
		}
		if len(byName) > 0 {
			// A connection arrives as an address; its name comes from the first
			// packet. TLS, HTTP and QUIC cover the web; nothing else is read.
			rules = append(rules,
				obj{"action": "sniff", "sniffer": []string{"tls", "http", "quic"}},
				obj{"protocol": "dns", "action": "hijack-dns"},
			)
			for _, r := range byName {
				r["outbound"] = listed
				rules = append(rules, obj(r))
			}
			// Names are looked up the same way as they are reached.
			for _, r := range byName {
				d := obj{}
				for k, v := range r {
					if k != "outbound" {
						d[k] = v
					}
				}
				d["server"] = listedDNS
				dnsRules = append(dnsRules, d)
			}
		}
	}

	localDNS := obj{"type": "local"}
	if opts.LocalDNS != "" {
		if localDNS, err = dnsServer(opts.LocalDNS); err != nil {
			return nil, skipped, err
		}
	}
	localDNS["tag"] = "local"

	cfg := obj{
		"log": obj{"level": opts.LogLevel, "timestamp": true},
		"dns": obj{
			"servers": []any{
				remoteDNS,
				localDNS,
			},
			"final":    dnsFinal,
			"strategy": dnsStrategy(opts.NoIPv6),
		},
		"inbounds":  inbounds,
		"outbounds": outbounds,
		"route": obj{
			"rules":                   rules,
			"final":                   routeFinal,
			"default_domain_resolver": "local",
		},
	}
	// Binding outbound sockets to the physical interface is only needed to keep
	// them out of our own TUN; in proxy mode it just adds failure modes (some
	// Windows security software rejects interface-bound sockets).
	if opts.Mode == ModeTUN {
		cfg["route"].(obj)["auto_detect_interface"] = true
	}
	if len(dnsRules) > 0 {
		cfg["dns"].(obj)["rules"] = dnsRules
	}
	if len(endpoints) > 0 {
		cfg["endpoints"] = endpoints
	}
	applyMesh(cfg, meshTags)
	return cfg, skipped, nil
}

func orInt(v, def int) int {
	if v == 0 {
		return def
	}
	return v
}

// dnsStrategy: IPv4 first (many networks have broken IPv6), or IPv4 only when IPv6 is switched off.
func dnsStrategy(noIPv6 bool) string {
	if noIPv6 {
		return "ipv4_only"
	}
	return "prefer_ipv4"
}

// convert maps one profile to a sing-box outbound tagged tag (or an endpoint
// for WireGuard and OpenVPN). extras are helper outbounds it depends on
// (ShadowTLS), tagged after tag.
func convert(p *profile.Profile, tag string) (out obj, isEndpoint bool, extras []obj, err error) {
	out, isEndpoint, extras, err = convertProfile(p, tag)
	if out != nil {
		out["tag"] = tag
	}
	return
}

func convertProfile(prof *profile.Profile, tag string) (out obj, isEndpoint bool, extras []obj, err error) {
	base := obj{"server": prof.Server, "server_port": prof.Port}
	switch prof.Protocol {
	case profile.VLESS:
		base["type"] = "vless"
		base["uuid"] = prof.UUID
		if prof.Flow != "" {
			base["flow"] = prof.Flow
		}
		addTLS(base, prof.TLS)
		addTransport(base, prof.Transport)
		addMultiplex(base, prof.Multiplex)
	case profile.VMess:
		base["type"] = "vmess"
		base["uuid"] = prof.UUID
		base["security"] = orDefault(prof.Method, "auto")
		base["alter_id"] = prof.AlterID
		addTLS(base, prof.TLS)
		addTransport(base, prof.Transport)
		addMultiplex(base, prof.Multiplex)
	case profile.Trojan:
		base["type"] = "trojan"
		base["password"] = prof.Password
		addTLS(base, prof.TLS)
		addTransport(base, prof.Transport)
		addMultiplex(base, prof.Multiplex)
	case profile.Shadowsocks:
		base["type"] = "shadowsocks"
		base["method"] = prof.Method
		base["password"] = prof.Password
		addMultiplex(base, prof.Multiplex)
		switch prof.Plugin {
		case "":
		case "shadow-tls":
			stls, err := shadowTLSOutbound(prof, tag+"-shadowtls")
			if err != nil {
				return nil, false, nil, err
			}
			base["detour"] = stls["tag"]
			extras = append(extras, stls)
		default:
			base["plugin"] = prof.Plugin
			base["plugin_opts"] = prof.PluginOpts
		}
	case profile.Hysteria2:
		base["type"] = "hysteria2"
		base["password"] = prof.Password
		if hy2 := prof.Hysteria2; hy2 != nil {
			if hy2.Obfs != "" {
				base["obfs"] = obj{"type": hy2.Obfs, "password": hy2.ObfsPassword}
			}
			if hy2.UpMbps > 0 {
				base["up_mbps"] = hy2.UpMbps
			}
			if hy2.DownMbps > 0 {
				base["down_mbps"] = hy2.DownMbps
			}
		}
		addTLS(base, tlsOrDefault(prof.TLS))
	case profile.TUIC:
		base["type"] = "tuic"
		base["uuid"] = prof.UUID
		base["password"] = prof.Password
		if t := prof.TUIC; t != nil {
			if t.CongestionControl != "" {
				base["congestion_control"] = t.CongestionControl
			}
			if t.UDPRelayMode != "" {
				base["udp_relay_mode"] = t.UDPRelayMode
			}
		}
		addTLS(base, tlsOrDefault(prof.TLS))
	case profile.Hysteria:
		base["type"] = "hysteria"
		if prof.Password != "" {
			base["auth_str"] = prof.Password
		}
		// Hysteria v1 needs bandwidth hints; these defaults suit mobile links.
		up, down := 10, 50
		if hy2 := prof.Hysteria2; hy2 != nil {
			if hy2.Obfs != "" {
				base["obfs"] = hy2.Obfs
			}
			if hy2.UpMbps > 0 {
				up = hy2.UpMbps
			}
			if hy2.DownMbps > 0 {
				down = hy2.DownMbps
			}
		}
		base["up_mbps"], base["down_mbps"] = up, down
		tlsOpts := tlsOrDefault(prof.TLS)
		if len(tlsOpts.ALPN) == 0 {
			c := *tlsOpts
			c.ALPN = []string{"hysteria"}
			tlsOpts = &c
		}
		addTLS(base, tlsOpts)
	case profile.AnyTLS:
		base["type"] = "anytls"
		base["password"] = prof.Password
		addTLS(base, tlsOrDefault(prof.TLS))
	case profile.SSH:
		base["type"] = "ssh"
		base["user"] = prof.Username
		if prof.Password != "" {
			base["password"] = prof.Password
		}
		if opts := prof.SSH; opts != nil {
			if opts.PrivateKey != "" {
				base["private_key"] = opts.PrivateKey
			}
			if opts.PrivateKeyPassphrase != "" {
				base["private_key_passphrase"] = opts.PrivateKeyPassphrase
			}
			if len(opts.HostKey) > 0 {
				base["host_key"] = opts.HostKey
			}
			if opts.ClientVersion != "" {
				base["client_version"] = opts.ClientVersion
			}
		}
	case profile.Naive:
		// Naive runs on Chromium's network stack (cronet): it takes only the
		// server name and an optional pinned certificate, no other TLS options.
		base["type"] = "naive"
		base["username"], base["password"] = prof.Username, prof.Password
		tls := obj{"enabled": true}
		if prof.TLS != nil {
			if prof.TLS.ServerName != "" {
				tls["server_name"] = prof.TLS.ServerName
			}
			if prof.TLS.Certificate != "" {
				tls["certificate"] = prof.TLS.Certificate
			}
			if prof.TLS.Insecure && prof.TLS.Certificate == "" {
				return nil, false, nil, fmt.Errorf("naive can't skip certificate checks; pin the server certificate instead")
			}
		}
		base["tls"] = tls
		if opts := prof.Naive; opts != nil {
			if opts.QUIC {
				base["quic"] = true
			}
			if len(opts.ExtraHeaders) > 0 {
				base["extra_headers"] = opts.ExtraHeaders
			}
		}
	case profile.WireGuard:
		ep, extras, err := wireguardEndpoint(prof, tag)
		return ep, true, extras, err
	case profile.OpenVPN:
		ep, err := openvpnEndpoint(prof)
		return ep, true, nil, err
	case profile.AmneziaWG:
		return nil, false, nil, fmt.Errorf("%w: amneziawg runs on the dedicated AWG engine (not sing-box)", ErrOtherEngine)
	case profile.DNSTT:
		return nil, false, nil, fmt.Errorf("%w: a DNS tunnel runs as a helper next to sing-box", ErrOtherEngine)
	default:
		return nil, false, nil, fmt.Errorf("protocol %q is not supported by the sing-box engine", prof.Protocol)
	}
	return base, false, extras, nil
}

// addMultiplex turns on sing-box's multiplexing for an outbound.
func addMultiplex(out obj, muxOpts *profile.Mux) {
	if !muxOpts.Enabled() {
		return
	}
	mux := obj{"enabled": true, "protocol": muxOpts.Protocol}
	if muxOpts.MaxConnections > 0 {
		mux["max_connections"] = muxOpts.MaxConnections
	}
	if muxOpts.MinStreams > 0 {
		mux["min_streams"] = muxOpts.MinStreams
	}
	if muxOpts.MaxStreams > 0 {
		mux["max_streams"] = muxOpts.MaxStreams
	}
	if muxOpts.Padding {
		mux["padding"] = true
	}
	out["multiplex"] = mux
}

// shadowTLSOutbound is the ShadowTLS layer under a Shadowsocks profile whose
// plugin is "shadow-tls" (options "host=<sni>;password=<pw>;version=<1-3>").
func shadowTLSOutbound(prof *profile.Profile, tag string) (obj, error) {
	opts := map[string]string{}
	for kv := range strings.SplitSeq(prof.PluginOpts, ";") {
		k, v, _ := strings.Cut(strings.TrimSpace(kv), "=")
		if k != "" {
			opts[k] = v
		}
	}
	version := 3
	if v := opts["version"]; v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 3 {
			return nil, fmt.Errorf("shadow-tls: invalid version %q", v)
		}
		version = n
	}
	if opts["host"] == "" {
		return nil, fmt.Errorf("shadow-tls: missing host")
	}
	tls := obj{"enabled": true, "server_name": opts["host"], "utls": obj{"enabled": true, "fingerprint": "chrome"}}
	if opts["insecure"] == "1" || opts["insecure"] == "true" {
		tls["insecure"] = true
	}
	out := obj{"type": "shadowtls", "tag": tag, "server": prof.Server, "server_port": prof.Port, "version": version, "tls": tls}
	if version > 1 {
		if opts["password"] == "" {
			return nil, fmt.Errorf("shadow-tls: missing password")
		}
		out["password"] = opts["password"]
	}
	return out, nil
}

// wireguardEndpoint is the WireGuard endpoint. With a proxy under it (WireGuard.Via), the proxy's outbound comes
// back as an extra and the endpoint detours through it.
func wireguardEndpoint(prof *profile.Profile, tag string) (obj, []obj, error) {
	wg := prof.WireGuard
	allowed := wg.AllowedIPs
	if len(allowed) == 0 {
		allowed = []string{"0.0.0.0/0", "::/0"}
	}
	peer := obj{
		"address":     prof.Server,
		"port":        prof.Port,
		"public_key":  wg.PeerPublicKey,
		"allowed_ips": allowed,
	}
	if wg.PreSharedKey != "" {
		peer["pre_shared_key"] = wg.PreSharedKey
	}
	if wg.Keepalive > 0 {
		peer["persistent_keepalive_interval"] = wg.Keepalive
	}
	if len(wg.Reserved) > 0 {
		peer["reserved"] = wg.Reserved
	}
	ep := obj{
		"type":        "wireguard",
		"address":     normalizePrefixes(wg.Address),
		"private_key": wg.PrivateKey,
		"peers":       []any{peer},
	}
	if wg.MTU > 0 {
		ep["mtu"] = wg.MTU
	}
	var extras []obj
	if via := strings.TrimSpace(wg.Via); via != "" {
		pv, err := importer.ParseLink(via)
		if err != nil {
			return nil, nil, fmt.Errorf("the proxy under WireGuard: %w", err)
		}
		if !slices.Contains(profile.ViaSchemes, strings.ToLower(strings.SplitN(via, "://", 2)[0])) {
			return nil, nil, fmt.Errorf("the proxy under WireGuard: %s cannot carry UDP", pv.Protocol)
		}
		viaTag := tag + "-via"
		out, isEndpoint, more, err := convertProfile(pv, viaTag)
		if err != nil {
			return nil, nil, fmt.Errorf("the proxy under WireGuard: %w", err)
		}
		if isEndpoint {
			return nil, nil, fmt.Errorf("the proxy under WireGuard cannot be %s", pv.Protocol)
		}
		out["tag"] = viaTag
		extras = slices.Concat(more, []obj{out})
		ep["detour"] = viaTag
	}
	return ep, extras, nil
}

// openvpnEndpoint maps an OpenVPN profile to sing-box's openvpn-client endpoint.
func openvpnEndpoint(prof *profile.Profile) (obj, error) {
	opts := prof.OpenVPN
	if opts == nil {
		return nil, fmt.Errorf("missing OpenVPN settings")
	}
	if opts.NeedsAuth && (prof.Username == "" || prof.Password == "") {
		return nil, profile.ErrNeedsCredentials
	}
	ep := obj{"type": "openvpn-client"}
	if len(opts.Remotes) == 0 {
		ep["server"], ep["server_port"], ep["network"] = prof.Server, prof.Port, orDefault(opts.Network, "udp")
	} else {
		servers := []any{obj{"server": prof.Server, "server_port": prof.Port, "network": orDefault(opts.Network, "udp")}}
		for _, r := range opts.Remotes {
			servers = append(servers, obj{"server": r.Server, "server_port": r.Port, "network": orDefault(r.Network, "udp")})
		}
		ep["servers"] = servers
	}
	if opts.RemoteRandom {
		ep["remote_random"] = true
	}
	if prof.Username != "" {
		ep["username"], ep["password"] = prof.Username, prof.Password
	}
	tls := obj{"certificate": []string{opts.CA}}
	if opts.Cert != "" {
		tls["client_certificate"] = []string{opts.Cert}
		tls["client_key"] = []string{opts.Key}
	}
	if opts.VerifyX509Name != "" {
		tls["server_name"] = opts.VerifyX509Name
		if opts.VerifyX509Type != "" {
			tls["server_name_type"] = opts.VerifyX509Type
		} else {
			tls["server_name_type"] = "subject"
		}
	}
	if opts.RemoteCertTLS != "" {
		tls["remote_certificate_tls"] = opts.RemoteCertTLS
	}
	if opts.TLSVersionMin != "" {
		tls["version_min"] = opts.TLSVersionMin
	}
	if opts.TLSCipher != "" {
		tls["cipher"] = opts.TLSCipher
	}
	if opts.ControlWrap != "" {
		cw := obj{"type": strings.ReplaceAll(opts.ControlWrap, "-", "_"), "key": []string{opts.ControlWrapKey}}
		if opts.ControlWrap == "tls-auth" {
			switch opts.KeyDirection {
			case "1":
				cw["direction"] = "client"
			case "0":
				cw["direction"] = "server"
			}
		}
		tls["control_wrap"] = cw
	}
	ep["tls"] = tls
	if len(opts.DataCiphers) > 0 {
		ep["data_ciphers"] = opts.DataCiphers
	}
	// In TLS mode a client's `cipher` is the fallback for servers without cipher negotiation.
	if fb := orDefault(opts.DataCiphersFallback, opts.Cipher); fb != "" {
		ep["data_ciphers_fallback"] = fb
	}
	if opts.Auth != "" {
		ep["auth"] = opts.Auth
	}
	if opts.Compression != "" {
		ep["compression"] = opts.Compression
	}
	if opts.CompressionLZO != "" {
		ep["compression_lzo"] = opts.CompressionLZO
	}
	if opts.MTU > 0 {
		ep["mtu"] = opts.MTU
	}
	if opts.MSSFix > 0 {
		ep["mss_fix"] = opts.MSSFix
	}
	return ep, nil
}

// normalizePrefixes adds a host prefix length to bare addresses.
func normalizePrefixes(addrs []string) []string {
	out := make([]string, 0, len(addrs))
	for _, a := range addrs {
		if !strings.Contains(a, "/") {
			if strings.Contains(a, ":") {
				a += "/128"
			} else {
				a += "/32"
			}
		}
		out = append(out, a)
	}
	return out
}

func addTLS(out obj, tlsOpts *profile.TLS) {
	if tlsOpts == nil || !tlsOpts.Enabled {
		return
	}
	tls := obj{"enabled": true}
	if tlsOpts.ServerName != "" {
		tls["server_name"] = tlsOpts.ServerName
	}
	if tlsOpts.Insecure {
		tls["insecure"] = true
	}
	if len(tlsOpts.ALPN) > 0 {
		tls["alpn"] = tlsOpts.ALPN
	}
	if tlsOpts.Fingerprint != "" {
		tls["utls"] = obj{"enabled": true, "fingerprint": tlsOpts.Fingerprint}
	}
	if r := tlsOpts.Reality; r != nil {
		tls["reality"] = obj{"enabled": true, "public_key": r.PublicKey, "short_id": r.ShortID}
	}
	if tlsOpts.Certificate != "" {
		tls["certificate"] = tlsOpts.Certificate
	}
	if tlsOpts.Fragment {
		tls["fragment"] = true
	}
	if tlsOpts.RecordFragment {
		tls["record_fragment"] = true
	}
	if echOpts := tlsOpts.ECH; echOpts.On() {
		ech := obj{"enabled": true}
		if c := strings.TrimSpace(echOpts.Config); c != "" {
			ech["config"] = strings.Split(strings.ReplaceAll(c, "\r\n", "\n"), "\n")
		}
		if echOpts.QueryServerName != "" {
			ech["query_server_name"] = echOpts.QueryServerName
		}
		tls["ech"] = ech
	}
	out["tls"] = tls
}

func addTransport(out obj, transport *profile.Transport) {
	if transport == nil {
		return
	}
	switch transport.Type {
	case "ws":
		tr := obj{"type": "ws", "path": orDefault(transport.Path, "/")}
		if transport.Host != "" {
			tr["headers"] = obj{"Host": transport.Host}
		}
		// v2ray links carry early data as ?ed=2048 in the path.
		if path, ed, ok := strings.Cut(tr["path"].(string), "?ed="); ok {
			if n, err := strconv.Atoi(ed); err == nil {
				tr["path"] = path
				tr["max_early_data"] = n
				tr["early_data_header_name"] = "Sec-WebSocket-Protocol"
			}
		}
		out["transport"] = tr
	case "httpupgrade":
		tr := obj{"type": "httpupgrade", "path": orDefault(transport.Path, "/")}
		if transport.Host != "" {
			tr["host"] = transport.Host
		}
		out["transport"] = tr
	case "grpc":
		out["transport"] = obj{"type": "grpc", "service_name": transport.ServiceName}
	case "http":
		tr := obj{"type": "http"}
		if transport.Path != "" {
			tr["path"] = transport.Path
		}
		if transport.Host != "" {
			tr["host"] = splitComma(transport.Host)
		}
		out["transport"] = tr
	}
}

// dnsServer converts a resolver URL into a sing-box DNS server.
func dnsServer(raw string) (obj, error) {
	if !strings.Contains(raw, "://") {
		raw = "udp://" + raw
	}
	uri, err := url.Parse(raw)
	if err != nil || uri.Hostname() == "" {
		return nil, fmt.Errorf("invalid DNS server %q", raw)
	}
	server := obj{"server": uri.Hostname()}
	if p := uri.Port(); p != "" {
		port, err := strconv.Atoi(p)
		if err != nil {
			return nil, fmt.Errorf("invalid DNS server port %q", p)
		}
		server["server_port"] = port
	}
	switch uri.Scheme {
	case "https":
		server["type"] = "https"
		if uri.Path != "" && uri.Path != "/dns-query" {
			server["path"] = uri.Path
		}
	case "tls", "tcp", "udp":
		server["type"] = uri.Scheme
	default:
		return nil, fmt.Errorf("unsupported DNS scheme %q (use https, tls, tcp or udp)", uri.Scheme)
	}
	return server, nil
}

func tlsOrDefault(tlsOpts *profile.TLS) *profile.TLS {
	if tlsOpts == nil {
		return &profile.TLS{Enabled: true}
	}
	tlsOpts.Enabled = true
	return tlsOpts
}

func splitComma(s string) []string {
	var out []string
	for v := range strings.SplitSeq(s, ",") {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	return out
}

func orDefault(s, def string) string {
	if s == "" {
		return def
	}
	return s
}

// Outbound converts one profile to a sing-box outbound tagged tag, or to an
// endpoint (isEndpoint) for WireGuard and OpenVPN. extras are helper
// outbounds it depends on (ShadowTLS) and must be included too.
func Outbound(p *profile.Profile, tag string) (out map[string]any, isEndpoint bool, extras []map[string]any, err error) {
	return convert(p, tag)
}

// torOutbound routes a Tor profile into the local Tor client's SOCKS5 port.
// helperOutbound routes a profile into a helper tunnel's local SOCKS5 port, logging in as the profile says.
func helperOutbound(helper HelperSocks, tag string) (obj, error) {
	host, port, err := net.SplitHostPort(helper.Addr)
	if err != nil || helper.Addr == "" {
		return nil, fmt.Errorf("the tunnel is not running")
	}
	n, err := strconv.Atoi(port)
	if err != nil {
		return nil, fmt.Errorf("bad tunnel address %q", helper.Addr)
	}
	out := obj{"type": "socks", "tag": tag, "server": host, "server_port": n, "version": "5"}
	if helper.Username != "" || helper.Password != "" {
		out["username"], out["password"] = helper.Username, helper.Password
	}
	return out, nil
}

func torOutbound(socks, tag string) (obj, error) {
	host, port, err := net.SplitHostPort(socks)
	if err != nil || socks == "" {
		return nil, fmt.Errorf("Tor is not running")
	}
	n, err := strconv.Atoi(port)
	if err != nil {
		return nil, fmt.Errorf("bad Tor SOCKS address %q", socks)
	}
	return obj{"type": "socks", "tag": tag, "server": host, "server_port": n, "version": "5"}, nil
}
