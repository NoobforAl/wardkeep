package importer

import (
	"encoding/json"
	"fmt"
	"net/url"
	"slices"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// parseURL parses a link and returns the URL with its host and port split out.
func parseURL(link string) (*url.URL, string, int, error) {
	uri, err := url.Parse(link)
	if err != nil {
		return nil, "", 0, fmt.Errorf("invalid link: %w", err)
	}
	host := uri.Hostname()
	if host == "" {
		return nil, "", 0, fmt.Errorf("missing server address")
	}
	port, err := strconv.Atoi(uri.Port())
	if err != nil {
		return nil, "", 0, fmt.Errorf("invalid port %q", uri.Port())
	}
	return uri, host, port, nil
}

func fragmentName(u *url.URL) string {
	return strings.TrimSpace(u.Fragment)
}

func splitList(s string) []string {
	if s == "" {
		return nil
	}
	var out []string
	for v := range strings.SplitSeq(s, ",") {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	return out
}

func truthy(s string) bool {
	switch strings.ToLower(s) {
	case "1", "true", "yes":
		return true
	}
	return false
}

// tlsExtrasFrom reads the handshake options of a link (see links.tlsExtraQuery); get returns "" for a missing one.
func tlsExtrasFrom(tlsOpts *profile.TLS, get func(string) string) {
	tlsOpts.Fragment, tlsOpts.RecordFragment = truthy(get("tlsfrag")), truthy(get("recfrag"))
	switch ech := get("ech"); {
	case ech == "":
	case truthy(ech):
		tlsOpts.ECH = &profile.ECH{Enabled: true, QueryServerName: get("echsni")}
	default:
		if cfg := profile.ECHPEM(ech); cfg != "" {
			tlsOpts.ECH = &profile.ECH{Enabled: true, Config: cfg, QueryServerName: get("echsni")}
		}
	}
	if tlsOpts.Reality != nil { // ECH and Reality exclude each other; the server is worth more than the option
		tlsOpts.ECH = nil
	}
}

// tlsFromQuery reads the common TLS/Reality query parameters used by
// v2rayN-style vless and trojan links.
func tlsFromQuery(query url.Values, defaultOn bool) *profile.TLS {
	security := query.Get("security")
	if security == "" && defaultOn {
		security = "tls"
	}
	if security == "" || security == "none" {
		return nil
	}
	tlsOpts := &profile.TLS{
		Enabled:     true,
		ServerName:  firstNonEmpty(query.Get("sni"), query.Get("peer")),
		ALPN:        splitList(query.Get("alpn")),
		Insecure:    truthy(query.Get("allowInsecure")) || truthy(query.Get("insecure")),
		Fingerprint: query.Get("fp"),
	}
	if security == "reality" {
		tlsOpts.Reality = &profile.Reality{PublicKey: query.Get("pbk"), ShortID: query.Get("sid")}
		if tlsOpts.Fingerprint == "" {
			tlsOpts.Fingerprint = "chrome"
		}
	}
	tlsExtrasFrom(tlsOpts, query.Get)
	return tlsOpts
}

// muxFrom reads the multiplexing parameters of a link (see links.muxQuery); get returns "" for a missing one.
func muxFrom(get func(string) string) *profile.Mux {
	proto := get("mux")
	if proto == "" {
		return nil
	}
	mux := &profile.Mux{Protocol: proto, Padding: truthy(get("muxpad"))}
	mux.MaxConnections, _ = strconv.Atoi(get("muxconn"))
	mux.MinStreams, _ = strconv.Atoi(get("muxmin"))
	mux.MaxStreams, _ = strconv.Atoi(get("muxmax"))
	return mux
}

// dropUnusableTLSExtras removes the handshake options from a profile whose protocol cannot use them (they are for
// TLS over TCP): an import keeps the server and loses the option.
func dropUnusableTLSExtras(prof *profile.Profile) {
	if prof.TLS == nil || slices.Contains([]string{profile.VLESS, profile.VMess, profile.Trojan, profile.AnyTLS}, prof.Protocol) {
		return
	}
	prof.TLS.Fragment, prof.TLS.RecordFragment, prof.TLS.ECH = false, false, nil
}

// attachMux sets a profile's multiplexing when it is usable for the protocol. An import should keep the server
// and lose the multiplexing, never the other way round, so what the protocol cannot do is dropped quietly.
func attachMux(prof *profile.Profile, mux *profile.Mux) {
	if !mux.Enabled() || !slices.Contains(profile.MuxProtocols, mux.Protocol) {
		return
	}
	switch prof.Protocol {
	case profile.VLESS:
		if prof.Flow != "" {
			return
		}
	case profile.VMess, profile.Trojan, profile.Shadowsocks:
	default:
		return
	}
	muxCopy := *mux
	muxCopy.MaxConnections, muxCopy.MinStreams, muxCopy.MaxStreams = max(muxCopy.MaxConnections, 0), max(muxCopy.MinStreams, 0), max(muxCopy.MaxStreams, 0)
	if muxCopy.MaxStreams > 0 {
		muxCopy.MaxConnections, muxCopy.MinStreams = 0, 0
	}
	prof.Multiplex = &muxCopy
}

func transportFromQuery(query url.Values) *profile.Transport {
	typ := query.Get("type")
	switch typ {
	case "", "tcp", "raw":
		if query.Get("headerType") == "http" {
			return &profile.Transport{Type: "http", Path: query.Get("path"), Host: query.Get("host")}
		}
		return nil
	case "ws", "httpupgrade":
		return &profile.Transport{Type: typ, Path: query.Get("path"), Host: query.Get("host")}
	case "grpc":
		return &profile.Transport{Type: "grpc", ServiceName: query.Get("serviceName")}
	case "http", "h2":
		return &profile.Transport{Type: "http", Path: query.Get("path"), Host: query.Get("host")}
	default:
		return &profile.Transport{Type: typ, Path: query.Get("path"), Host: query.Get("host")}
	}
}

func firstNonEmpty(v ...string) string {
	for _, s := range v {
		if s != "" {
			return s
		}
	}
	return ""
}

// vless://uuid@host:port?security=reality&sni=..&pbk=..&sid=..&flow=..&type=ws&path=..#name
func parseVLESS(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	prof := &profile.Profile{
		Name:      fragmentName(uri),
		Protocol:  profile.VLESS,
		Server:    host,
		Port:      port,
		UUID:      uri.User.Username(),
		Flow:      query.Get("flow"),
		TLS:       tlsFromQuery(query, false),
		Transport: transportFromQuery(query),
	}
	attachMux(prof, muxFrom(query.Get))
	return prof, nil
}

// trojan://password@host:port?sni=..&type=ws#name — TLS is on by default.
func parseTrojan(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	prof := &profile.Profile{
		Name:      fragmentName(uri),
		Protocol:  profile.Trojan,
		Server:    host,
		Port:      port,
		Password:  uri.User.Username(),
		TLS:       tlsFromQuery(query, true),
		Transport: transportFromQuery(query),
	}
	attachMux(prof, muxFrom(query.Get))
	return prof, nil
}

// vmess://base64(json) in the v2rayN format.
func parseVMess(link string) (*profile.Profile, error) {
	body := strings.TrimPrefix(link[strings.Index(link, "://")+3:], "/")
	decoded, ok := decodeBase64(body)
	if !ok {
		return nil, fmt.Errorf("vmess: body is not base64")
	}
	var v map[string]any
	if err := json.Unmarshal([]byte(decoded), &v); err != nil {
		return nil, fmt.Errorf("vmess: %w", err)
	}
	str := func(k string) string {
		switch x := v[k].(type) {
		case string:
			return x
		case float64:
			return strconv.Itoa(int(x))
		}
		return ""
	}
	port, err := strconv.Atoi(str("port"))
	if err != nil {
		return nil, fmt.Errorf("vmess: invalid port %q", str("port"))
	}
	aid, _ := strconv.Atoi(str("aid"))
	prof := &profile.Profile{
		Name:     str("ps"),
		Protocol: profile.VMess,
		Server:   str("add"),
		Port:     port,
		UUID:     str("id"),
		AlterID:  aid,
		Method:   firstNonEmpty(str("scy"), "auto"),
	}
	if str("tls") == "tls" {
		prof.TLS = &profile.TLS{
			Enabled:     true,
			ServerName:  firstNonEmpty(str("sni"), str("host")),
			ALPN:        splitList(str("alpn")),
			Fingerprint: str("fp"),
		}
		tlsExtrasFrom(prof.TLS, str)
	}
	query := url.Values{}
	query.Set("type", str("net"))
	query.Set("path", str("path"))
	query.Set("host", str("host"))
	query.Set("headerType", str("type"))
	query.Set("serviceName", str("path"))
	prof.Transport = transportFromQuery(query)
	attachMux(prof, muxFrom(str))
	return prof, nil
}

// ss://base64(method:password)@host:port#name (SIP002) or
// ss://base64(method:password@host:port)#name (legacy).
func parseShadowsocks(link string) (*profile.Profile, error) {
	rest := link[len("ss://"):]
	name := ""
	if i := strings.Index(rest, "#"); i >= 0 {
		name, _ = url.PathUnescape(rest[i+1:])
		rest = rest[:i]
	}
	if !strings.Contains(rest, "@") {
		decoded, ok := decodeBase64(rest)
		if !ok {
			return nil, fmt.Errorf("ss: invalid legacy link")
		}
		rest = decoded
	}
	uri, err := url.Parse("ss://" + rest)
	if err != nil {
		return nil, fmt.Errorf("ss: %w", err)
	}
	host := uri.Hostname()
	port, err := strconv.Atoi(uri.Port())
	if err != nil || host == "" {
		return nil, fmt.Errorf("ss: invalid server address")
	}
	method, password := "", ""
	if pw, ok := uri.User.Password(); ok {
		method, password = uri.User.Username(), pw
	} else if decoded, ok := decodeBase64(uri.User.Username()); ok {
		method, password, _ = strings.Cut(decoded, ":")
	} else {
		return nil, fmt.Errorf("ss: invalid user info")
	}
	prof := &profile.Profile{
		Name:     name,
		Protocol: profile.Shadowsocks,
		Server:   host,
		Port:     port,
		Method:   method,
		Password: password,
	}
	if plugin := uri.Query().Get("plugin"); plugin != "" {
		prof.Plugin, prof.PluginOpts, _ = strings.Cut(plugin, ";")
	}
	attachMux(prof, muxFrom(uri.Query().Get))
	return prof, nil
}

// hysteria2://auth@host:port?sni=..&obfs=salamander&obfs-password=..&insecure=1#name
func parseHysteria2(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	password := uri.User.Username()
	if pw, ok := uri.User.Password(); ok {
		password += ":" + pw
	}
	prof := &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.Hysteria2,
		Server:   host,
		Port:     port,
		Password: password,
		TLS: &profile.TLS{
			Enabled:    true,
			ServerName: query.Get("sni"),
			Insecure:   truthy(query.Get("insecure")),
			ALPN:       splitList(query.Get("alpn")),
		},
	}
	if obfs := query.Get("obfs"); obfs != "" {
		prof.Hysteria2 = &profile.Hy2{Obfs: obfs, ObfsPassword: query.Get("obfs-password")}
	}
	return prof, nil
}

// tuic://uuid:password@host:port?congestion_control=bbr&alpn=h3&sni=..#name
func parseTUIC(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	pw, _ := uri.User.Password()
	return &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.TUIC,
		Server:   host,
		Port:     port,
		UUID:     uri.User.Username(),
		Password: pw,
		TLS: &profile.TLS{
			Enabled:    true,
			ServerName: query.Get("sni"),
			ALPN:       splitList(firstNonEmpty(query.Get("alpn"), "h3")),
			Insecure:   truthy(query.Get("allow_insecure")) || truthy(query.Get("insecure")),
		},
		TUIC: &profile.TUICOpts{
			CongestionControl: query.Get("congestion_control"),
			UDPRelayMode:      query.Get("udp_relay_mode"),
		},
	}, nil
}

// wireguard://privatekey@host:port?publickey=..&address=..&mtu=..&reserved=1,2,3#name
func parseWireGuardLink(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	priv, _ := url.PathUnescape(uri.User.Username())
	wg := &profile.WG{
		PrivateKey:    priv,
		PeerPublicKey: firstNonEmpty(query.Get("publickey"), query.Get("peer_public_key")),
		PreSharedKey:  firstNonEmpty(query.Get("presharedkey"), query.Get("pre_shared_key")),
		Address:       splitList(firstNonEmpty(query.Get("address"), query.Get("ip"))),
	}
	wg.MTU, _ = strconv.Atoi(query.Get("mtu"))
	wg.AllowedIPs = splitList(firstNonEmpty(query.Get("allowedips"), query.Get("allowed_ips")))
	wg.DNS = splitList(query.Get("dns"))
	wg.Via = strings.TrimSpace(query.Get("via"))
	wg.Keepalive, _ = strconv.Atoi(firstNonEmpty(query.Get("keepalive"), query.Get("persistent_keepalive")))
	for _, r := range splitList(query.Get("reserved")) {
		n, err := strconv.Atoi(r)
		if err != nil {
			return nil, fmt.Errorf("wireguard: invalid reserved %q", r)
		}
		wg.Reserved = append(wg.Reserved, n)
	}
	proto := profile.WireGuard
	// awg:// is the same link with AmneziaWG's obfuscation parameters.
	if strings.EqualFold(uri.Scheme, "awg") {
		proto = profile.AmneziaWG
		wg.Via = ""
		for k := range amneziaKeys {
			if v := query.Get(k); v != "" {
				if wg.Amnezia == nil {
					wg.Amnezia = map[string]string{}
				}
				wg.Amnezia[k] = v
			}
		}
	}
	return &profile.Profile{
		Name:      fragmentName(uri),
		Protocol:  proto,
		Server:    host,
		Port:      port,
		WireGuard: wg,
	}, nil
}
