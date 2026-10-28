package importer

import (
	"fmt"
	"strconv"
	"strings"

	yaml "go.yaml.in/yaml/v3"

	"github.com/NoobforAl/omnitun/core/profile"
)

// looksLikeClash reports whether text is a Clash / Clash.Meta (mihomo) config.
func looksLikeClash(text string) bool {
	for line := range strings.SplitSeq(text, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "proxies:") {
			return true
		}
	}
	return false
}

// clashProxy is the subset of Clash proxy fields we map to profiles.
type clashProxy map[string]any

func (p clashProxy) str(keys ...string) string {
	for _, k := range keys {
		switch v := p[k].(type) {
		case string:
			if v != "" {
				return v
			}
		case int:
			return strconv.Itoa(v)
		case float64:
			return strconv.FormatFloat(v, 'f', -1, 64)
		}
	}
	return ""
}

func (p clashProxy) num(key string) int {
	switch v := p[key].(type) {
	case int:
		return v
	case float64:
		return int(v)
	case string:
		n, _ := strconv.Atoi(strings.TrimSpace(strings.Fields(v + " 0")[0]))
		return n
	}
	return 0
}

func (p clashProxy) boolean(key string) bool {
	switch v := p[key].(type) {
	case bool:
		return v
	case string:
		return truthy(v)
	}
	return false
}

func (p clashProxy) sub(key string) clashProxy {
	// yaml.v3 decodes nested maps into the parent's named type.
	switch m := p[key].(type) {
	case clashProxy:
		return m
	case map[string]any:
		return m
	}
	return clashProxy{}
}

func (p clashProxy) list(key string) []string {
	switch v := p[key].(type) {
	case []any:
		var out []string
		for _, x := range v {
			out = append(out, fmt.Sprint(x))
		}
		return out
	case string:
		return splitList(v)
	}
	return nil
}

// ImportClash converts the proxies of a Clash YAML config.
func ImportClash(text string) (*Result, error) {
	var doc struct {
		Proxies []clashProxy `yaml:"proxies"`
	}
	if err := yaml.Unmarshal([]byte(text), &doc); err != nil {
		return nil, fmt.Errorf("clash: %w", err)
	}
	res := &Result{}
	for _, cp := range doc.Proxies {
		prof, err := clashToProfile(cp)
		if err != nil {
			res.Errors = append(res.Errors, fmt.Sprintf("%s: %v", cp.str("name"), err))
			continue
		}
		if err := prof.Validate(); err != nil {
			res.Errors = append(res.Errors, err.Error())
			continue
		}
		prof.EnsureID()
		res.Profiles = append(res.Profiles, prof)
	}
	if len(res.Profiles) == 0 {
		if len(res.Errors) > 0 {
			return res, fmt.Errorf("no usable proxies: %s", res.Errors[0])
		}
		return nil, fmt.Errorf("clash config has no proxies")
	}
	return res, nil
}

func clashToProfile(cp clashProxy) (*profile.Profile, error) {
	prof := &profile.Profile{
		Name:   cp.str("name"),
		Server: cp.str("server"),
		Port:   cp.num("port"),
	}
	// A stable source so IDs survive re-imports of the same proxy.
	prof.Source = fmt.Sprintf("clash:%s:%s:%d:%s", cp.str("type"), prof.Server, prof.Port, prof.Name)
	tls := func(defaultOn bool) *profile.TLS {
		if !defaultOn && !cp.boolean("tls") && cp.sub("reality-opts")["public-key"] == nil {
			return nil
		}
		tlsOpts := &profile.TLS{
			Enabled:     true,
			ServerName:  cp.str("servername", "sni"),
			Insecure:    cp.boolean("skip-cert-verify"),
			ALPN:        cp.list("alpn"),
			Fingerprint: cp.str("client-fingerprint"),
		}
		if ro := cp.sub("reality-opts"); ro.str("public-key") != "" {
			tlsOpts.Reality = &profile.Reality{PublicKey: ro.str("public-key"), ShortID: ro.str("short-id")}
			if tlsOpts.Fingerprint == "" {
				tlsOpts.Fingerprint = "chrome"
			}
		}
		if eo := cp.sub("ech-opts"); eo.boolean("enable") && tlsOpts.Reality == nil {
			tlsOpts.ECH = &profile.ECH{Enabled: true, Config: profile.ECHPEM(eo.str("config")), QueryServerName: eo.str("query-server-name")}
		}
		return tlsOpts
	}
	transport := func() *profile.Transport {
		switch cp.str("network") {
		case "ws":
			ws := cp.sub("ws-opts")
			return &profile.Transport{Type: "ws", Path: ws.str("path"), Host: ws.sub("headers").str("Host", "host")}
		case "grpc":
			return &profile.Transport{Type: "grpc", ServiceName: cp.sub("grpc-opts").str("grpc-service-name")}
		case "h2", "http":
			h2Opts := cp.sub("h2-opts")
			if len(h2Opts) == 0 {
				h2Opts = cp.sub("http-opts")
			}
			path := h2Opts.str("path")
			if l := h2Opts.list("path"); len(l) > 0 {
				path = l[0]
			}
			host := ""
			if l := h2Opts.list("host"); len(l) > 0 {
				host = strings.Join(l, ",")
			}
			return &profile.Transport{Type: "http", Path: path, Host: host}
		case "httpupgrade":
			hu := cp.sub("http-upgrade-opts")
			return &profile.Transport{Type: "httpupgrade", Path: hu.str("path"), Host: hu.str("host")}
		}
		return nil
	}

	switch typ := cp.str("type"); typ {
	case "ss":
		prof.Protocol = profile.Shadowsocks
		prof.Method = cp.str("cipher")
		prof.Password = cp.str("password")
		// Clash plugin-opts → SIP003 plugin option strings.
		po := cp.sub("plugin-opts")
		switch cp.str("plugin") {
		case "":
		case "obfs":
			prof.Plugin = "obfs-local"
			prof.PluginOpts = "obfs=" + po.str("mode")
			if h := po.str("host"); h != "" {
				prof.PluginOpts += ";obfs-host=" + h
			}
		case "v2ray-plugin":
			prof.Plugin = "v2ray-plugin"
			opts := []string{"mode=" + po.str("mode")}
			if po.boolean("tls") {
				opts = append(opts, "tls")
			}
			for _, k := range []string{"host", "path"} {
				if v := po.str(k); v != "" {
					opts = append(opts, k+"="+v)
				}
			}
			prof.PluginOpts = strings.Join(opts, ";")
		case "shadow-tls":
			prof.Plugin = "shadow-tls"
			prof.PluginOpts = fmt.Sprintf("host=%s;password=%s;version=%s", po.str("host"), po.str("password"), firstNonEmpty(po.str("version"), "2"))
		default:
			return nil, fmt.Errorf("unsupported shadowsocks plugin %q", cp.str("plugin"))
		}
	case "vmess":
		prof.Protocol = profile.VMess
		prof.UUID = cp.str("uuid")
		prof.AlterID = cp.num("alterId")
		prof.Method = cp.str("cipher")
		prof.TLS, prof.Transport = tls(false), transport()
	case "vless":
		prof.Protocol = profile.VLESS
		prof.UUID = cp.str("uuid")
		prof.Flow = cp.str("flow")
		prof.TLS, prof.Transport = tls(false), transport()
	case "trojan":
		prof.Protocol = profile.Trojan
		prof.Password = cp.str("password")
		prof.TLS, prof.Transport = tls(true), transport()
	case "hysteria2", "hy2":
		prof.Protocol = profile.Hysteria2
		prof.Password = cp.str("password", "auth")
		prof.TLS = tls(true)
		if obfs := cp.str("obfs"); obfs != "" {
			prof.Hysteria2 = &profile.Hy2{Obfs: obfs, ObfsPassword: cp.str("obfs-password")}
		}
	case "tuic":
		prof.Protocol = profile.TUIC
		prof.UUID = cp.str("uuid")
		prof.Password = cp.str("password")
		prof.TLS = tls(true)
		prof.TUIC = &profile.TUICOpts{
			CongestionControl: cp.str("congestion-controller"),
			UDPRelayMode:      cp.str("udp-relay-mode"),
		}
	case "hysteria":
		prof.Protocol = profile.Hysteria
		prof.Password = cp.str("auth-str", "auth_str", "auth")
		prof.TLS = tls(true)
		h := &profile.Hy2{Obfs: cp.str("obfs")}
		h.UpMbps, h.DownMbps = cp.num("up"), cp.num("down")
		prof.Hysteria2 = h
	case "anytls":
		prof.Protocol = profile.AnyTLS
		prof.Password = cp.str("password")
		prof.TLS = tls(true)
	case "ssh":
		prof.Protocol = profile.SSH
		prof.Username = cp.str("username", "user")
		prof.Password = cp.str("password")
		o := &profile.SSHOpts{PrivateKey: cp.str("private-key"), PrivateKeyPassphrase: cp.str("private-key-passphrase"), HostKey: cp.list("host-key")}
		if o.PrivateKey != "" || len(o.HostKey) > 0 {
			prof.SSH = o
		}
	case "wireguard":
		prof.Protocol = profile.WireGuard
		wg := &profile.WG{
			PrivateKey:    cp.str("private-key"),
			PeerPublicKey: cp.str("public-key"),
			PreSharedKey:  cp.str("pre-shared-key"),
			MTU:           cp.num("mtu"),
			AllowedIPs:    cp.list("allowed-ips"),
		}
		for _, a := range []string{cp.str("ip"), cp.str("ipv6")} {
			if a != "" {
				wg.Address = append(wg.Address, a)
			}
		}
		if r, ok := cp["reserved"].([]any); ok {
			for _, x := range r {
				n, _ := strconv.Atoi(fmt.Sprint(x))
				wg.Reserved = append(wg.Reserved, n)
			}
		}
		if len(cp.list("amnezia-wg-option")) > 0 || len(cp.sub("amnezia-wg-option")) > 0 {
			prof.Protocol = profile.AmneziaWG
		}
		prof.WireGuard = wg
	default:
		return nil, fmt.Errorf("unsupported proxy type %q", typ)
	}
	dropUnusableTLSExtras(prof)
	if sm := cp.sub("smux"); sm.boolean("enabled") {
		attachMux(prof, &profile.Mux{Protocol: firstNonEmpty(sm.str("protocol"), "smux"), MaxConnections: sm.num("max-connections"),
			MinStreams: sm.num("min-streams"), MaxStreams: sm.num("max-streams"), Padding: sm.boolean("padding")})
	}
	return prof, nil
}
