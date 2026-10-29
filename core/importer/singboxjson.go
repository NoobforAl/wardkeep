package importer

import (
	"encoding/json"
	"fmt"
	"slices"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

type sbTLS struct {
	Certificate stringList `json:"certificate"`
	Enabled     bool       `json:"enabled"`
	ServerName  string     `json:"server_name"`
	Insecure    bool       `json:"insecure"`
	ALPN        []string   `json:"alpn"`
	UTLS        *struct {
		Fingerprint string `json:"fingerprint"`
	} `json:"utls"`
	Reality *struct {
		PublicKey string `json:"public_key"`
		ShortID   string `json:"short_id"`
	} `json:"reality"`
	Fragment       bool `json:"fragment"`
	RecordFragment bool `json:"record_fragment"`
	ECH            *struct {
		Enabled         bool       `json:"enabled"`
		Config          stringList `json:"config"`
		QueryServerName string     `json:"query_server_name"`
	} `json:"ech"`
}

type sbMux struct {
	Enabled        bool   `json:"enabled"`
	Protocol       string `json:"protocol"`
	MaxConnections int    `json:"max_connections"`
	MinStreams     int    `json:"min_streams"`
	MaxStreams     int    `json:"max_streams"`
	Padding        bool   `json:"padding"`
}

type sbTransport struct {
	Type        string            `json:"type"`
	Path        string            `json:"path"`
	Headers     map[string]any    `json:"headers"`
	Host        any               `json:"host"`
	ServiceName string            `json:"service_name"`
	Extra       map[string]string `json:"-"`
}

type sbPeer struct {
	Address    string   `json:"address"`
	Port       int      `json:"port"`
	PublicKey  string   `json:"public_key"`
	PreShared  string   `json:"pre_shared_key"`
	AllowedIPs []string `json:"allowed_ips"`
	Reserved   []int    `json:"reserved"`
}

type sbOutbound struct {
	Type         string            `json:"type"`
	Tag          string            `json:"tag"`
	Server       string            `json:"server"`
	ServerPort   int               `json:"server_port"`
	UUID         string            `json:"uuid"`
	Username     string            `json:"username"`
	QUIC         bool              `json:"quic"`
	ExtraHeaders map[string]string `json:"extra_headers"`
	Password     string            `json:"password"`
	Method       string            `json:"method"`
	Security     string            `json:"security"`
	AlterID      int               `json:"alter_id"`
	Flow         string            `json:"flow"`
	Plugin       string            `json:"plugin"`
	PluginOpts   string            `json:"plugin_opts"`
	TLS          *sbTLS            `json:"tls"`
	Transport    *sbTransport      `json:"transport"`
	Multiplex    *sbMux            `json:"multiplex"`
	Obfs         *struct {
		Type     string `json:"type"`
		Password string `json:"password"`
	} `json:"obfs"`
	CongestionControl string `json:"congestion_control"`
	UDPRelayMode      string `json:"udp_relay_mode"`
	// WireGuard endpoint
	Address    []string `json:"address"`
	PrivateKey string   `json:"private_key"`
	MTU        int      `json:"mtu"`
	Peers      []sbPeer `json:"peers"`
}

// ImportSingBoxJSON converts the proxy outbounds and WireGuard endpoints of a
// sing-box config. Groups, direct/block/dns outbounds are skipped.
func ImportSingBoxJSON(text string) (*Result, error) {
	var doc struct {
		Outbounds []json.RawMessage `json:"outbounds"`
		Endpoints []json.RawMessage `json:"endpoints"`
		// ExtraLinks carries what sing-box cannot express (AmneziaWG): Wardkeep
		// servers list those profiles as share links next to the outbounds.
		ExtraLinks []string `json:"extra_links"`
	}
	if err := json.Unmarshal([]byte(text), &doc); err != nil {
		return nil, fmt.Errorf("sing-box JSON: %w", err)
	}
	res := &Result{}
	all := slices.Concat(doc.Outbounds, doc.Endpoints)
	// ShadowTLS outbounds are layers under Shadowsocks ones (via "detour").
	shadowTLS := map[string]sbShadowTLS{}
	for _, raw := range all {
		var st sbShadowTLS
		if json.Unmarshal(raw, &st) == nil && st.Type == "shadowtls" {
			shadowTLS[st.Tag] = st
		}
	}
	for _, raw := range all {
		var head struct {
			Type   string `json:"type"`
			Tag    string `json:"tag"`
			Detour string `json:"detour"`
		}
		if err := json.Unmarshal(raw, &head); err != nil {
			res.Errors = append(res.Errors, err.Error())
			continue
		}
		switch head.Type {
		case "direct", "block", "dns", "selector", "urltest", "shadowtls", "":
			continue
		}
		var prof *profile.Profile
		var err error
		switch head.Type {
		case "openvpn-client":
			prof, err = sbOpenVPNToProfile(raw)
		case "hysteria":
			prof, err = sbHysteriaToProfile(raw)
		case "ssh":
			prof, err = sbSSHToProfile(raw)
		default:
			var o sbOutbound
			if err = json.Unmarshal(raw, &o); err == nil {
				prof, err = sbToProfile(o)
			}
		}
		if err == nil && head.Detour != "" {
			if st, ok := shadowTLS[head.Detour]; ok && prof.Protocol == profile.Shadowsocks {
				// The ShadowTLS server is the address clients actually dial.
				prof.Server, prof.Port = st.Server, st.ServerPort
				prof.Plugin = "shadow-tls"
				prof.PluginOpts = fmt.Sprintf("host=%s;password=%s;version=%d", st.TLS.ServerName, st.Password, max(st.Version, 1))
				if st.TLS.Insecure {
					prof.PluginOpts += ";insecure=1"
				}
			} else {
				err = fmt.Errorf("detour %q is not supported", head.Detour)
			}
		}
		if err == nil {
			err = prof.Validate()
		}
		if err != nil {
			res.Errors = append(res.Errors, fmt.Sprintf("%s: %v", head.Tag, err))
			continue
		}
		prof.EnsureID()
		res.Profiles = append(res.Profiles, prof)
	}
	for _, link := range doc.ExtraLinks {
		if p, err := ParseLink(link); err == nil {
			res.Profiles = append(res.Profiles, p)
		} else {
			res.Errors = append(res.Errors, fmt.Sprintf("%s: %v", truncate(link, 40), err))
		}
	}
	if len(res.Profiles) == 0 {
		if len(res.Errors) > 0 {
			return res, fmt.Errorf("no usable outbounds: %s", res.Errors[0])
		}
		return nil, fmt.Errorf("sing-box config has no proxy outbounds")
	}
	return res, nil
}

func sbToProfile(outbound sbOutbound) (*profile.Profile, error) {
	prof := &profile.Profile{
		Name:   outbound.Tag,
		Server: outbound.Server,
		Port:   outbound.ServerPort,
		UUID:   outbound.UUID, Password: outbound.Password, Flow: outbound.Flow, AlterID: outbound.AlterID,
	}
	prof.Source = fmt.Sprintf("sing-box:%s:%s:%d:%s", outbound.Type, outbound.Server, outbound.ServerPort, outbound.Tag)
	if tlsOpts := outbound.TLS; tlsOpts != nil && tlsOpts.Enabled {
		prof.TLS = &profile.TLS{Enabled: true, ServerName: tlsOpts.ServerName, Insecure: tlsOpts.Insecure, ALPN: tlsOpts.ALPN, Certificate: tlsOpts.Certificate.joined()}
		if tlsOpts.UTLS != nil {
			prof.TLS.Fingerprint = tlsOpts.UTLS.Fingerprint
		}
		if tlsOpts.Reality != nil && tlsOpts.Reality.PublicKey != "" {
			prof.TLS.Reality = &profile.Reality{PublicKey: tlsOpts.Reality.PublicKey, ShortID: tlsOpts.Reality.ShortID}
		}
		prof.TLS.Fragment, prof.TLS.RecordFragment = tlsOpts.Fragment, tlsOpts.RecordFragment
		if e := tlsOpts.ECH; e != nil && e.Enabled && prof.TLS.Reality == nil {
			prof.TLS.ECH = &profile.ECH{Enabled: true, Config: profile.ECHPEM(e.Config.joined()), QueryServerName: e.QueryServerName}
		}
	}
	if tr := outbound.Transport; tr != nil {
		pt := &profile.Transport{Type: tr.Type, Path: tr.Path, ServiceName: tr.ServiceName}
		switch h := tr.Host.(type) {
		case string:
			pt.Host = h
		case []any:
			var hosts []string
			for _, x := range h {
				hosts = append(hosts, fmt.Sprint(x))
			}
			pt.Host = strings.Join(hosts, ",")
		}
		if hv, ok := tr.Headers["Host"]; ok && pt.Host == "" {
			pt.Host = fmt.Sprint(hv)
		}
		prof.Transport = pt
	}
	switch outbound.Type {
	case "vless":
		prof.Protocol = profile.VLESS
	case "vmess":
		prof.Protocol = profile.VMess
		prof.Method = outbound.Security
	case "trojan":
		prof.Protocol = profile.Trojan
	case "anytls":
		prof.Protocol = profile.AnyTLS
	case "naive":
		prof.Protocol = profile.Naive
		prof.Username = outbound.Username
		if outbound.QUIC || len(outbound.ExtraHeaders) > 0 {
			prof.Naive = &profile.NaiveOpts{QUIC: outbound.QUIC, ExtraHeaders: outbound.ExtraHeaders}
		}
	case "shadowsocks":
		prof.Protocol = profile.Shadowsocks
		prof.Method, prof.Plugin, prof.PluginOpts = outbound.Method, outbound.Plugin, outbound.PluginOpts
	case "hysteria2":
		prof.Protocol = profile.Hysteria2
		if outbound.Obfs != nil && outbound.Obfs.Type != "" {
			prof.Hysteria2 = &profile.Hy2{Obfs: outbound.Obfs.Type, ObfsPassword: outbound.Obfs.Password}
		}
	case "tuic":
		prof.Protocol = profile.TUIC
		prof.TUIC = &profile.TUICOpts{CongestionControl: outbound.CongestionControl, UDPRelayMode: outbound.UDPRelayMode}
	case "wireguard":
		if len(outbound.Peers) == 0 {
			return nil, fmt.Errorf("wireguard without peers")
		}
		peer := outbound.Peers[0]
		prof.Protocol = profile.WireGuard
		prof.Server, prof.Port = peer.Address, peer.Port
		prof.WireGuard = &profile.WG{
			PrivateKey: outbound.PrivateKey, PeerPublicKey: peer.PublicKey, PreSharedKey: peer.PreShared,
			Address: outbound.Address, AllowedIPs: peer.AllowedIPs, Reserved: peer.Reserved, MTU: outbound.MTU,
		}
	default:
		return nil, fmt.Errorf("unsupported outbound type %q", outbound.Type)
	}
	dropUnusableTLSExtras(prof)
	if m := outbound.Multiplex; m != nil && m.Enabled {
		attachMux(prof, &profile.Mux{Protocol: firstNonEmpty(m.Protocol, "smux"), MaxConnections: m.MaxConnections,
			MinStreams: m.MinStreams, MaxStreams: m.MaxStreams, Padding: m.Padding})
	}
	return prof, nil
}

// sbOpenVPN is sing-box's openvpn-client endpoint (the fields Wardkeep maps).
type sbOpenVPN struct {
	Tag        string `json:"tag"`
	Server     string `json:"server"`
	ServerPort int    `json:"server_port"`
	Network    string `json:"network"`
	Servers    []struct {
		Server     string `json:"server"`
		ServerPort int    `json:"server_port"`
		Network    string `json:"network"`
	} `json:"servers"`
	RemoteRandom bool   `json:"remote_random"`
	Username     string `json:"username"`
	Password     string `json:"password"`
	TLS          struct {
		Certificate          stringList `json:"certificate"`
		ClientCertificate    stringList `json:"client_certificate"`
		ClientKey            stringList `json:"client_key"`
		ServerName           string     `json:"server_name"`
		ServerNameType       string     `json:"server_name_type"`
		RemoteCertificateTLS string     `json:"remote_certificate_tls"`
		VersionMin           string     `json:"version_min"`
		Cipher               string     `json:"cipher"`
		ControlWrap          *struct {
			Type      string     `json:"type"`
			Key       stringList `json:"key"`
			Direction string     `json:"direction"`
		} `json:"control_wrap"`
	} `json:"tls"`
	DataCiphers         stringList `json:"data_ciphers"`
	DataCiphersFallback string     `json:"data_ciphers_fallback"`
	Auth                string     `json:"auth"`
	Compression         string     `json:"compression"`
	CompressionLZO      string     `json:"compression_lzo"`
	MTU                 int        `json:"mtu"`
	MSSFix              int        `json:"mss_fix"`
}

// stringList accepts a JSON string or an array of strings (sing-box "Listable").
type stringList []string

func (l *stringList) UnmarshalJSON(b []byte) error {
	var one string
	if json.Unmarshal(b, &one) == nil {
		*l = []string{one}
		return nil
	}
	var many []string
	if err := json.Unmarshal(b, &many); err != nil {
		return err
	}
	*l = many
	return nil
}

func (l stringList) joined() string { return strings.Join(l, "\n") }

func sbOpenVPNToProfile(raw json.RawMessage) (*profile.Profile, error) {
	var ovpn sbOpenVPN
	if err := json.Unmarshal(raw, &ovpn); err != nil {
		return nil, err
	}
	if ovpn.TLS.Certificate == nil {
		return nil, fmt.Errorf("only certificate-based (TLS mode) OpenVPN is supported")
	}
	opts := &profile.OVPN{
		Network: orDefault(ovpn.Network, "udp"), RemoteRandom: ovpn.RemoteRandom,
		CA: ovpn.TLS.Certificate.joined(), Cert: ovpn.TLS.ClientCertificate.joined(), Key: ovpn.TLS.ClientKey.joined(),
		VerifyX509Name: ovpn.TLS.ServerName, VerifyX509Type: ovpn.TLS.ServerNameType,
		RemoteCertTLS: ovpn.TLS.RemoteCertificateTLS, TLSVersionMin: ovpn.TLS.VersionMin, TLSCipher: ovpn.TLS.Cipher,
		DataCiphers: ovpn.DataCiphers, DataCiphersFallback: ovpn.DataCiphersFallback, Auth: ovpn.Auth,
		Compression: ovpn.Compression, CompressionLZO: ovpn.CompressionLZO, MTU: ovpn.MTU, MSSFix: ovpn.MSSFix,
		NeedsAuth: ovpn.Username != "",
	}
	if cw := ovpn.TLS.ControlWrap; cw != nil && cw.Type != "" {
		opts.ControlWrap, opts.ControlWrapKey = strings.ReplaceAll(cw.Type, "_", "-"), cw.Key.joined()
		switch cw.Direction {
		case "client":
			opts.KeyDirection = "1"
		case "server":
			opts.KeyDirection = "0"
		}
	}
	prof := &profile.Profile{
		Name: ovpn.Tag, Protocol: profile.OpenVPN, Server: ovpn.Server, Port: ovpn.ServerPort,
		Username: ovpn.Username, Password: ovpn.Password, OpenVPN: opts,
	}
	for i, r := range ovpn.Servers {
		if i == 0 && prof.Server == "" {
			prof.Server, prof.Port, opts.Network = r.Server, r.ServerPort, orDefault(r.Network, "udp")
			continue
		}
		opts.Remotes = append(opts.Remotes, profile.OVPNRemote{Server: r.Server, Port: r.ServerPort, Network: orDefault(r.Network, "udp")})
	}
	prof.Source = fmt.Sprintf("sing-box:openvpn:%s:%d:%s", prof.Server, prof.Port, prof.Name)
	return prof, nil
}

type sbShadowTLS struct {
	Type       string `json:"type"`
	Tag        string `json:"tag"`
	Server     string `json:"server"`
	ServerPort int    `json:"server_port"`
	Version    int    `json:"version"`
	Password   string `json:"password"`
	TLS        struct {
		ServerName string `json:"server_name"`
		Insecure   bool   `json:"insecure"`
	} `json:"tls"`
}

func sbHysteriaToProfile(raw json.RawMessage) (*profile.Profile, error) {
	var outbound struct {
		Tag        string `json:"tag"`
		Server     string `json:"server"`
		ServerPort int    `json:"server_port"`
		AuthStr    string `json:"auth_str"`
		Obfs       string `json:"obfs"`
		UpMbps     int    `json:"up_mbps"`
		DownMbps   int    `json:"down_mbps"`
		TLS        *sbTLS `json:"tls"`
	}
	if err := json.Unmarshal(raw, &outbound); err != nil {
		return nil, err
	}
	prof := &profile.Profile{
		Name: outbound.Tag, Protocol: profile.Hysteria, Server: outbound.Server, Port: outbound.ServerPort, Password: outbound.AuthStr,
		Hysteria2: &profile.Hy2{Obfs: outbound.Obfs, UpMbps: outbound.UpMbps, DownMbps: outbound.DownMbps},
		TLS:       &profile.TLS{Enabled: true},
	}
	if t := outbound.TLS; t != nil {
		prof.TLS.ServerName, prof.TLS.Insecure, prof.TLS.ALPN = t.ServerName, t.Insecure, t.ALPN
	}
	prof.Source = fmt.Sprintf("sing-box:hysteria:%s:%d:%s", prof.Server, prof.Port, prof.Name)
	return prof, nil
}

func sbSSHToProfile(raw json.RawMessage) (*profile.Profile, error) {
	var outbound struct {
		Tag                  string     `json:"tag"`
		Server               string     `json:"server"`
		ServerPort           int        `json:"server_port"`
		User                 string     `json:"user"`
		Password             string     `json:"password"`
		PrivateKey           stringList `json:"private_key"`
		PrivateKeyPassphrase string     `json:"private_key_passphrase"`
		HostKey              stringList `json:"host_key"`
		ClientVersion        string     `json:"client_version"`
	}
	if err := json.Unmarshal(raw, &outbound); err != nil {
		return nil, err
	}
	port := outbound.ServerPort
	if port == 0 {
		port = 22
	}
	prof := &profile.Profile{Name: outbound.Tag, Protocol: profile.SSH, Server: outbound.Server, Port: port, Username: outbound.User, Password: outbound.Password}
	if len(outbound.PrivateKey) > 0 || len(outbound.HostKey) > 0 || outbound.ClientVersion != "" {
		prof.SSH = &profile.SSHOpts{
			PrivateKey: outbound.PrivateKey.joined(), PrivateKeyPassphrase: outbound.PrivateKeyPassphrase,
			HostKey: outbound.HostKey, ClientVersion: outbound.ClientVersion,
		}
	}
	prof.Source = fmt.Sprintf("sing-box:ssh:%s:%d:%s", prof.Server, prof.Port, prof.Name)
	return prof, nil
}
