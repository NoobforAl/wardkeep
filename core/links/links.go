// Package links turns a profile back into a share link (the reverse of
// core/importer). The server uses it to hand out links, and the app to share
// a profile as a link or QR code. Export followed by importer.ParseLink gives
// the same profile back.
package links

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"sort"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// ErrNoLink means the protocol has no share-link format (OpenVPN travels as
// a config file).
var ErrNoLink = errors.New("this protocol has no share link; export it as a config file")

// Export returns the share link for prof.
func Export(prof *profile.Profile) (string, error) {
	switch prof.Protocol {
	case profile.VLESS:
		return vless(prof), nil
	case profile.VMess:
		return vmess(prof)
	case profile.Trojan:
		return trojan(prof), nil
	case profile.Shadowsocks:
		return shadowsocks(prof), nil
	case profile.Hysteria2:
		return hysteria2(prof), nil
	case profile.Hysteria:
		return hysteria(prof), nil
	case profile.TUIC:
		return tuic(prof), nil
	case profile.AnyTLS:
		return anytls(prof), nil
	case profile.SSH:
		return ssh(prof), nil
	case profile.Naive:
		return naive(prof), nil
	case profile.IKEv2:
		return ikev2(prof), nil
	case profile.SSTP:
		return sstp(prof), nil
	case profile.Tor:
		return tor(prof), nil
	case profile.Tailscale:
		return tailscale(prof)
	case profile.DNSTT:
		return dnstt(prof), nil
	case profile.WireGuard, profile.AmneziaWG:
		return wireguard(prof)
	}
	return "", fmt.Errorf("%w (%s)", ErrNoLink, prof.Protocol)
}

func hostPort(p *profile.Profile) string {
	return net.JoinHostPort(p.Server, strconv.Itoa(p.Port))
}

// query is an ordered query string: parameters keep the order they were
// added in, which keeps links stable and readable.
type query struct{ keys, vals []string }

func (q *query) add(k, v string) {
	if v != "" {
		q.keys, q.vals = append(q.keys, k), append(q.vals, v)
	}
}

func (q *query) addFlag(k string, on bool) {
	if on {
		q.add(k, "1")
	}
}

func (q *query) String() string {
	var sb strings.Builder
	for i, k := range q.keys {
		if i > 0 {
			sb.WriteByte('&')
		}
		sb.WriteString(url.QueryEscape(k) + "=" + url.QueryEscape(q.vals[i]))
	}
	return sb.String()
}

// build assembles scheme://userinfo@host:port/path?query#name.
func build(scheme, userinfo, host, path string, params *query, name string) string {
	var sb strings.Builder
	sb.WriteString(scheme + "://")
	if userinfo != "" {
		sb.WriteString(userinfo + "@")
	}
	sb.WriteString(host + path)
	if s := params.String(); s != "" {
		sb.WriteString("?" + s)
	}
	if name != "" {
		sb.WriteString("#" + url.PathEscape(name))
	}
	return sb.String()
}

// insecure adds the flag under the names different clients read.
func insecure(q *query, t *profile.TLS, names ...string) {
	if t != nil && t.Insecure {
		for _, n := range names {
			q.add(n, "1")
		}
	}
}

// tlsExtraQuery writes the handshake options: tlsfrag=1, recfrag=1, ech=<base64 config | 1> and echsni.
func tlsExtraQuery(params *query, tlsOpts *profile.TLS) {
	if tlsOpts == nil {
		return
	}
	params.addFlag("tlsfrag", tlsOpts.Fragment)
	params.addFlag("recfrag", tlsOpts.RecordFragment)
	if ech := tlsOpts.ECH; ech.On() {
		if c := profile.ECHBase64(ech.Config); c != "" {
			params.add("ech", c)
		} else {
			params.add("ech", "1")
		}
		params.add("echsni", ech.QueryServerName)
	}
}

// tlsQuery writes the v2rayN-style TLS/Reality parameters.
func tlsQuery(params *query, tlsOpts *profile.TLS, flow string) {
	switch {
	case tlsOpts == nil || !tlsOpts.Enabled:
		params.add("security", "none")
		return
	case tlsOpts.Reality != nil:
		params.add("security", "reality")
	default:
		params.add("security", "tls")
	}
	params.add("flow", flow)
	params.add("sni", tlsOpts.ServerName)
	params.add("fp", tlsOpts.Fingerprint)
	params.add("alpn", strings.Join(tlsOpts.ALPN, ","))
	if tlsOpts.Reality != nil {
		params.add("pbk", tlsOpts.Reality.PublicKey)
		params.add("sid", tlsOpts.Reality.ShortID)
	}
	insecure(params, tlsOpts, "insecure", "allowInsecure", "allow_insecure")
	tlsExtraQuery(params, tlsOpts)
}

func transportQuery(params *query, tr *profile.Transport) {
	if tr == nil {
		params.add("type", "tcp")
		return
	}
	params.add("type", tr.Type)
	params.add("host", tr.Host)
	params.add("path", tr.Path)
	params.add("serviceName", tr.ServiceName)
}

// muxQuery writes the multiplexing parameters: mux=<protocol>, muxpad=1, muxconn, muxmin, muxmax.
func muxQuery(params *query, mux *profile.Mux) {
	if !mux.Enabled() {
		return
	}
	params.add("mux", mux.Protocol)
	params.addFlag("muxpad", mux.Padding)
	if mux.MaxConnections > 0 {
		params.add("muxconn", strconv.Itoa(mux.MaxConnections))
	}
	if mux.MinStreams > 0 {
		params.add("muxmin", strconv.Itoa(mux.MinStreams))
	}
	if mux.MaxStreams > 0 {
		params.add("muxmax", strconv.Itoa(mux.MaxStreams))
	}
}

func vless(prof *profile.Profile) string {
	params := &query{}
	transportQuery(params, prof.Transport)
	tlsQuery(params, prof.TLS, prof.Flow)
	if prof.TLS == nil || !prof.TLS.Enabled {
		params.add("flow", prof.Flow)
	}
	muxQuery(params, prof.Multiplex)
	return build("vless", url.PathEscape(prof.UUID), hostPort(prof), "", params, prof.Name)
}

func trojan(prof *profile.Profile) string {
	params := &query{}
	if prof.Transport != nil {
		transportQuery(params, prof.Transport)
	}
	tlsQuery(params, prof.TLS, "")
	muxQuery(params, prof.Multiplex)
	return build("trojan", url.PathEscape(prof.Password), hostPort(prof), "", params, prof.Name)
}

func vmess(prof *profile.Profile) (string, error) {
	fields := map[string]any{
		"v": "2", "ps": prof.Name, "add": prof.Server, "port": strconv.Itoa(prof.Port), "id": prof.UUID,
		"aid": strconv.Itoa(prof.AlterID), "scy": orDefault(prof.Method, "auto"), "net": "tcp", "type": "none",
	}
	if tr := prof.Transport; tr != nil {
		fields["net"] = tr.Type
		switch tr.Type {
		case "grpc":
			fields["path"] = tr.ServiceName
		default:
			fields["path"], fields["host"] = tr.Path, tr.Host
		}
	}
	if t := prof.TLS; t != nil && t.Enabled {
		fields["tls"], fields["sni"], fields["fp"], fields["alpn"] = "tls", t.ServerName, t.Fingerprint, strings.Join(t.ALPN, ",")
	}
	if tlsOpts := prof.TLS; tlsOpts != nil && tlsOpts.Enabled {
		if tlsOpts.Fragment {
			fields["tlsfrag"] = "1"
		}
		if tlsOpts.RecordFragment {
			fields["recfrag"] = "1"
		}
		if e := tlsOpts.ECH; e.On() {
			fields["ech"], fields["echsni"] = orDefault(profile.ECHBase64(e.Config), "1"), e.QueryServerName
		}
	}
	if mux := prof.Multiplex; mux.Enabled() {
		fields["mux"] = mux.Protocol
		if mux.Padding {
			fields["muxpad"] = "1"
		}
		for k, n := range map[string]int{"muxconn": mux.MaxConnections, "muxmin": mux.MinStreams, "muxmax": mux.MaxStreams} {
			if n > 0 {
				fields[k] = strconv.Itoa(n)
			}
		}
	}
	raw, err := json.Marshal(fields)
	if err != nil {
		return "", err
	}
	return "vmess://" + base64.StdEncoding.EncodeToString(raw), nil
}

func shadowsocks(prof *profile.Profile) string {
	userinfo := base64.RawURLEncoding.EncodeToString([]byte(prof.Method + ":" + prof.Password))
	params := &query{}
	if prof.Plugin != "" {
		plugin := prof.Plugin
		if prof.PluginOpts != "" {
			plugin += ";" + prof.PluginOpts
		}
		params.add("plugin", plugin)
	}
	muxQuery(params, prof.Multiplex)
	return build("ss", userinfo, hostPort(prof), "", params, prof.Name)
}

func hysteria2(prof *profile.Profile) string {
	params := &query{}
	if prof.TLS != nil {
		params.add("sni", prof.TLS.ServerName)
		params.add("alpn", strings.Join(prof.TLS.ALPN, ","))
		insecure(params, prof.TLS, "insecure", "allowInsecure", "allow_insecure")
	}
	if h := prof.Hysteria2; h != nil {
		params.add("obfs", h.Obfs)
		params.add("obfs-password", h.ObfsPassword)
	}
	return build("hysteria2", userinfoPassword(prof.Password), hostPort(prof), "", params, prof.Name)
}

// userinfoPassword escapes a password that may contain "user:pass".
func userinfoPassword(pw string) string {
	user, pass, ok := strings.Cut(pw, ":")
	if !ok {
		return url.PathEscape(pw)
	}
	return url.PathEscape(user) + ":" + url.PathEscape(pass)
}

func hysteria(prof *profile.Profile) string {
	params := &query{}
	params.add("protocol", "udp")
	params.add("auth", prof.Password)
	if prof.TLS != nil {
		params.add("peer", prof.TLS.ServerName)
		params.add("alpn", strings.Join(prof.TLS.ALPN, ","))
		insecure(params, prof.TLS, "insecure")
	}
	if hy2 := prof.Hysteria2; hy2 != nil {
		if hy2.UpMbps > 0 {
			params.add("upmbps", strconv.Itoa(hy2.UpMbps))
		}
		if hy2.DownMbps > 0 {
			params.add("downmbps", strconv.Itoa(hy2.DownMbps))
		}
		params.add("obfsParam", hy2.Obfs)
	}
	return build("hysteria", "", hostPort(prof), "", params, prof.Name)
}

func tuic(prof *profile.Profile) string {
	params := &query{}
	if t := prof.TUIC; t != nil {
		params.add("congestion_control", t.CongestionControl)
		params.add("udp_relay_mode", t.UDPRelayMode)
	}
	if prof.TLS != nil {
		params.add("alpn", strings.Join(prof.TLS.ALPN, ","))
		params.add("sni", prof.TLS.ServerName)
		insecure(params, prof.TLS, "insecure", "allowInsecure", "allow_insecure")
	}
	return build("tuic", url.PathEscape(prof.UUID)+":"+url.PathEscape(prof.Password), hostPort(prof), "", params, prof.Name)
}

func anytls(prof *profile.Profile) string {
	params := &query{}
	if prof.TLS != nil {
		params.add("sni", prof.TLS.ServerName)
		params.add("fp", prof.TLS.Fingerprint)
		params.add("alpn", strings.Join(prof.TLS.ALPN, ","))
		insecure(params, prof.TLS, "insecure", "allowInsecure", "allow_insecure")
		tlsExtraQuery(params, prof.TLS)
	}
	return build("anytls", url.PathEscape(prof.Password), hostPort(prof), "/", params, prof.Name)
}

func ssh(prof *profile.Profile) string {
	params := &query{}
	if opts := prof.SSH; opts != nil {
		params.add("pk", opts.PrivateKey)
		params.add("pkp", opts.PrivateKeyPassphrase)
		params.add("hk", strings.Join(opts.HostKey, ","))
		params.add("client_version", opts.ClientVersion)
	}
	userinfo := url.PathEscape(prof.Username)
	if prof.Password != "" {
		userinfo += ":" + url.PathEscape(prof.Password)
	}
	return build("ssh", userinfo, hostPort(prof), "", params, prof.Name)
}

func naive(prof *profile.Profile) string {
	scheme, params := "naive+https", &query{}
	if prof.TLS != nil {
		params.add("sni", prof.TLS.ServerName)
	}
	if opts := prof.Naive; opts != nil {
		if opts.QUIC {
			scheme = "naive+quic"
		}
		if len(opts.ExtraHeaders) > 0 {
			keys := make([]string, 0, len(opts.ExtraHeaders))
			for k := range opts.ExtraHeaders {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			lines := make([]string, len(keys))
			for i, k := range keys {
				lines[i] = k + ": " + opts.ExtraHeaders[k]
			}
			params.add("extra-headers", strings.Join(lines, "\r\n"))
		}
	}
	userinfo := url.PathEscape(prof.Username) + ":" + url.PathEscape(prof.Password)
	return build(scheme, userinfo, hostPort(prof), "/", params, prof.Name)
}

func ikev2(prof *profile.Profile) string {
	params := &query{}
	opts := prof.IKEv2
	if opts == nil {
		opts = &profile.IKEv2Opts{Auth: "eap"}
	}
	params.add("auth", opts.Auth)
	params.add("psk", opts.PSK)
	params.add("remote_id", opts.RemoteID)
	params.add("local_id", opts.LocalID)
	params.add("ca", opts.CACert)
	if opts.MTU > 0 {
		params.add("mtu", strconv.Itoa(opts.MTU))
	}
	params.addFlag("tcp", opts.TCP)
	params.addFlag("system", opts.System)
	userinfo := ""
	if prof.Username != "" {
		userinfo = url.PathEscape(prof.Username)
		if prof.Password != "" {
			userinfo += ":" + url.PathEscape(prof.Password)
		}
	}
	return build("ikev2", userinfo, hostPort(prof), "", params, prof.Name)
}

func sstp(prof *profile.Profile) string {
	params := &query{}
	if prof.TLS != nil && !prof.TLS.Insecure {
		params.add("insecure", "0") // the parser's default is insecure=1
	}
	userinfo := url.PathEscape(prof.Username) + ":" + url.PathEscape(prof.Password)
	return build("sstp", userinfo, hostPort(prof), "", params, prof.Name)
}

// tor is one line, so a Tor profile with the user's own bridges can sit in a list of links (a shared group).
func tor(prof *profile.Profile) string {
	kind, bridges := "", []string(nil)
	if prof.Tor != nil {
		kind, bridges = prof.Tor.Builtin, prof.Tor.Bridges
	}
	params := &query{}
	for _, b := range bridges {
		params.add("bridge", b)
	}
	// The name a link without one would get back: no need to carry it.
	name := prof.Name
	switch {
	case kind != "" && name == "Tor ("+kind+")",
		kind == "" && len(bridges) == 0 && name == "Tor",
		kind == "" && len(bridges) > 0 && name == "Tor (custom bridges)":
		name = ""
	}
	return build("tor", "", kind, "", params, name)
}

func orDefault(s, d string) string {
	if s == "" {
		return d
	}
	return s
}

func wireguard(prof *profile.Profile) (string, error) {
	wgOpts := prof.WireGuard
	if wgOpts == nil || wgOpts.PrivateKey == "" {
		return "", errors.New("the WireGuard profile has no private key")
	}
	params := &query{}
	params.add("publickey", wgOpts.PeerPublicKey)
	params.add("presharedkey", wgOpts.PreSharedKey)
	params.add("address", strings.Join(wgOpts.Address, ","))
	params.add("allowedips", strings.Join(wgOpts.AllowedIPs, ","))
	params.add("dns", strings.Join(wgOpts.DNS, ","))
	if wgOpts.MTU > 0 {
		params.add("mtu", strconv.Itoa(wgOpts.MTU))
	}
	if wgOpts.Keepalive > 0 {
		params.add("keepalive", strconv.Itoa(wgOpts.Keepalive))
	}
	if prof.Protocol == profile.WireGuard {
		params.add("via", wgOpts.Via)
	}
	if len(wgOpts.Reserved) > 0 {
		parts := make([]string, len(wgOpts.Reserved))
		for i, r := range wgOpts.Reserved {
			parts[i] = strconv.Itoa(r)
		}
		params.add("reserved", strings.Join(parts, ","))
	}
	scheme := "wireguard"
	if prof.Protocol == profile.AmneziaWG {
		scheme = "awg"
		keys := make([]string, 0, len(wgOpts.Amnezia))
		for k := range wgOpts.Amnezia {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			params.add(k, wgOpts.Amnezia[k])
		}
	}
	return build(scheme, url.PathEscape(wgOpts.PrivateKey), hostPort(prof), "", params, prof.Name), nil
}

// dnstt is dnstt://<server key>@<domain>?resolver=...&resolver=...&user=...&pass=...#name. The key is public, so it
// travels as the user part of the link, the way a host-and-key pair is written elsewhere.
func dnstt(prof *profile.Profile) string {
	opts := prof.DNSTT
	if opts == nil {
		opts = &profile.DNSTTOpts{}
	}
	params := &query{}
	for _, r := range opts.Resolvers {
		params.add("resolver", r)
	}
	params.add("user", prof.Username)
	params.add("pass", prof.Password)
	return build("dnstt", url.PathEscape(opts.PubKey), opts.Domain, "", params, prof.Name)
}
