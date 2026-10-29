// Package profile defines the protocol-neutral connection profile used across
// the client, the engine and the server CLI.
package profile

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net/url"
	"slices"
	"strings"
)

// ErrNeedsCredentials means the profile needs a username and password before connecting.
var ErrNeedsCredentials = errors.New("needs a username and password")

// Protocol identifiers.
const (
	VLESS       = "vless"
	VMess       = "vmess"
	Trojan      = "trojan"
	Shadowsocks = "shadowsocks"
	Hysteria2   = "hysteria2"
	TUIC        = "tuic"
	WireGuard   = "wireguard"
	AmneziaWG   = "amneziawg"
	Naive       = "naive"
	Tor         = "tor"
	OpenVPN     = "openvpn"
	Hysteria    = "hysteria" // v1
	AnyTLS      = "anytls"
	SSH         = "ssh"
	Tailscale   = "tailscale" // mesh VPN: Tailscale, or a Headscale control server
	DNSTT       = "dnstt"     // a TCP tunnel inside DNS queries, for networks where only DNS gets out
)

// Profile is one connectable server configuration.
type Profile struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Protocol string `json:"protocol"`
	Server   string `json:"server"`
	Port     int    `json:"port"`

	// Credentials. Which fields are used depends on Protocol.
	UUID     string `json:"uuid,omitempty"`
	Password string `json:"password,omitempty"`
	Username string `json:"username,omitempty"`
	Method   string `json:"method,omitempty"` // shadowsocks cipher, vmess security
	Flow     string `json:"flow,omitempty"`   // vless flow, e.g. xtls-rprx-vision
	AlterID  int    `json:"alter_id,omitempty"`

	TLS        *TLS           `json:"tls,omitempty"`
	Transport  *Transport     `json:"transport,omitempty"`
	WireGuard  *WG            `json:"wireguard,omitempty"`
	Hysteria2  *Hy2           `json:"hysteria2,omitempty"`
	TUIC       *TUICOpts      `json:"tuic,omitempty"`
	OpenVPN    *OVPN          `json:"openvpn,omitempty"`
	SSH        *SSHOpts       `json:"ssh,omitempty"`
	Naive      *NaiveOpts     `json:"naive,omitempty"`
	Tor        *TorOpts       `json:"tor,omitempty"`
	Tailscale  *TailscaleOpts `json:"tailscale,omitempty"`
	DNSTT      *DNSTTOpts     `json:"dnstt,omitempty"`
	Plugin     string         `json:"plugin,omitempty"` // shadowsocks SIP003 plugin
	PluginOpts string         `json:"plugin_opts,omitempty"`
	// Multiplex carries many connections over one (VLESS, VMess, Trojan, Shadowsocks).
	Multiplex *Mux `json:"multiplex,omitempty"`

	// Source is the original link or file text the profile came from.
	Source string `json:"source,omitempty"`
}

// TLS settings shared by TLS-based protocols.
type TLS struct {
	Enabled     bool     `json:"enabled"`
	ServerName  string   `json:"server_name,omitempty"`
	ALPN        []string `json:"alpn,omitempty"`
	Insecure    bool     `json:"insecure,omitempty"`
	Fingerprint string   `json:"fingerprint,omitempty"` // uTLS fingerprint
	Reality     *Reality `json:"reality,omitempty"`
	// Certificate is a PEM certificate to trust (pin) instead of the system
	// CAs, e.g. a server's self-signed certificate.
	Certificate string `json:"certificate,omitempty"`
	// Fragment splits the first packet of the TLS handshake in two, and RecordFragment splits its TLS record, so a
	// filter that reads the server name from the first packet does not see it whole. Only for TLS over TCP.
	Fragment       bool `json:"fragment,omitempty"`
	RecordFragment bool `json:"record_fragment,omitempty"`
	// ECH hides the server name inside the handshake (Encrypted Client Hello).
	ECH *ECH `json:"ech,omitempty"`
}

// ECH is Encrypted Client Hello. It works only with a server that supports it, and not with Reality.
type ECH struct {
	Enabled bool `json:"enabled"`
	// Config is the server's ECH configuration as a PEM "ECH CONFIGS" block; empty looks it up in DNS.
	Config string `json:"config,omitempty"`
	// QueryServerName is the name to look the configuration up under; empty is the TLS server name.
	QueryServerName string `json:"query_server_name,omitempty"`
}

// On reports whether ECH is switched on.
func (e *ECH) On() bool { return e != nil && e.Enabled }

const (
	echBegin = "-----BEGIN ECH CONFIGS-----"
	echEnd   = "-----END ECH CONFIGS-----"
)

// ECHPEM wraps a base64 ECH configuration (as links carry it) in the PEM block sing-box reads. A PEM block is
// returned as it is, and anything that is not base64 comes back empty.
func ECHPEM(raw string) string {
	raw = strings.TrimSpace(raw)
	if strings.HasPrefix(raw, "-----") {
		return raw
	}
	raw = strings.Join(strings.Fields(raw), "")
	if raw == "" {
		return ""
	}
	if _, err := base64.StdEncoding.DecodeString(raw); err != nil {
		return ""
	}
	var sb strings.Builder
	sb.WriteString(echBegin + "\n")
	for len(raw) > 64 {
		sb.WriteString(raw[:64] + "\n")
		raw = raw[64:]
	}
	sb.WriteString(raw + "\n" + echEnd)
	return sb.String()
}

// ECHBase64 is the base64 body of a PEM ECH configuration, the form links carry.
func ECHBase64(pem string) string {
	pem = strings.TrimSpace(pem)
	pem = strings.TrimPrefix(pem, echBegin)
	pem = strings.TrimSuffix(pem, echEnd)
	return strings.Join(strings.Fields(pem), "")
}

// Reality settings for VLESS+Reality.
type Reality struct {
	PublicKey string `json:"public_key"`
	ShortID   string `json:"short_id,omitempty"`
}

// Mux is sing-box's multiplexing: many streams over few connections, so a page
// that opens thirty connections costs one handshake. The server has to allow it.
// A Mux with no Protocol is off.
type Mux struct {
	// Protocol is "smux", "yamux" or "h2mux".
	Protocol       string `json:"protocol,omitempty"`
	MaxConnections int    `json:"max_connections,omitempty"`
	MinStreams     int    `json:"min_streams,omitempty"`
	// MaxStreams cannot be combined with MaxConnections or MinStreams.
	MaxStreams int  `json:"max_streams,omitempty"`
	Padding    bool `json:"padding,omitempty"`
}

// MuxProtocols are the multiplexing protocols sing-box speaks.
var MuxProtocols = []string{"smux", "yamux", "h2mux"}

// Enabled reports whether multiplexing is on.
func (m *Mux) Enabled() bool { return m != nil && m.Protocol != "" }

// Transport is the V2Ray-style transport layer (ws, grpc, http, httpupgrade).
type Transport struct {
	Type        string `json:"type"`
	Path        string `json:"path,omitempty"`
	Host        string `json:"host,omitempty"`
	ServiceName string `json:"service_name,omitempty"`
}

// WG holds WireGuard and AmneziaWG settings.
type WG struct {
	PrivateKey    string   `json:"private_key"`
	PeerPublicKey string   `json:"peer_public_key"`
	PreSharedKey  string   `json:"pre_shared_key,omitempty"`
	Address       []string `json:"address"`
	AllowedIPs    []string `json:"allowed_ips,omitempty"`
	DNS           []string `json:"dns,omitempty"`
	MTU           int      `json:"mtu,omitempty"`
	Reserved      []int    `json:"reserved,omitempty"`
	Keepalive     int      `json:"keepalive,omitempty"`
	// Via is the share link of a proxy that carries the WireGuard packets (WireGuard over TCP, for networks that
	// block UDP). The proxy has to pass UDP. WireGuard only, not AmneziaWG.
	Via string `json:"via,omitempty"`
	// Amnezia holds AmneziaWG obfuscation parameters (Jc, Jmin, Jmax, S1, S2, H1-H4).
	Amnezia map[string]string `json:"amnezia,omitempty"`
}

// ViaSchemes are the link schemes of the proxies that can carry WireGuard: the ones that pass UDP.
var ViaSchemes = []string{"vless", "vmess", "trojan", "ss", "hysteria2", "hy2", "tuic"}

// TorOpts configures a Tor profile (Server and Port are unused).
type TorOpts struct {
	// Builtin picks Tor Browser's built-in bridges: "obfs4", "snowflake" or
	// "meek"; empty with no Bridges connects to Tor directly.
	Builtin string `json:"builtin,omitempty"`
	// Bridges are custom bridge lines (as in a torrc, without "Bridge ").
	Bridges []string `json:"bridges,omitempty"`
}

// TailscaleOpts configures a mesh profile (Server and Port are unused; the
// control server is ControlURL). The auth key is Profile.Password.
type TailscaleOpts struct {
	// ControlURL is the coordination server, e.g. https://headscale.example.com;
	// empty is Tailscale's own.
	ControlURL string `json:"control_url,omitempty"`
	// Hostname is the name this device has in the mesh; empty uses the device's own.
	Hostname string `json:"hostname,omitempty"`
	// ExitNode is the name or address of the device whose connection is used
	// for everything; empty reaches only the mesh and uses the normal connection otherwise.
	ExitNode string `json:"exit_node,omitempty"`
	// AcceptRoutes uses the subnets other devices offer (a home network).
	AcceptRoutes bool `json:"accept_routes,omitempty"`
	// Ephemeral removes this device from the mesh when it goes offline.
	Ephemeral bool `json:"ephemeral,omitempty"`
}

// NaiveOpts holds NaiveProxy options. User and password are in Username/Password.
type NaiveOpts struct {
	QUIC         bool              `json:"quic,omitempty"` // HTTP/3 instead of HTTP/2
	ExtraHeaders map[string]string `json:"extra_headers,omitempty"`
}

// SSHOpts holds SSH tunnel options. User and password are in Username/Password.
type SSHOpts struct {
	PrivateKey           string   `json:"private_key,omitempty"` // PEM
	PrivateKeyPassphrase string   `json:"private_key_passphrase,omitempty"`
	HostKey              []string `json:"host_key,omitempty"` // authorized_keys format; empty = accept any
	ClientVersion        string   `json:"client_version,omitempty"`
}

// Hy2 holds Hysteria2 options; Hysteria v1 uses Obfs (a plain obfuscation
// password) and the bandwidth fields.
type Hy2 struct {
	Obfs         string `json:"obfs,omitempty"`
	ObfsPassword string `json:"obfs_password,omitempty"`
	UpMbps       int    `json:"up_mbps,omitempty"`
	DownMbps     int    `json:"down_mbps,omitempty"`
}

// TUICOpts holds TUIC v5 options.
type TUICOpts struct {
	CongestionControl string `json:"congestion_control,omitempty"`
	UDPRelayMode      string `json:"udp_relay_mode,omitempty"`
}

// OVPN holds OpenVPN client settings, mostly as written in a .ovpn file.
// Username/Password (auth-user-pass) live in Profile.Username/Password.
type OVPN struct {
	// Network is the transport of the first remote: "udp" or "tcp".
	Network string `json:"network"`
	// Remotes are the additional `remote` lines after the first one
	// (which is Profile.Server/Port), tried in order.
	Remotes      []OVPNRemote `json:"remotes,omitempty"`
	RemoteRandom bool         `json:"remote_random,omitempty"`

	CA   string `json:"ca"`             // PEM
	Cert string `json:"cert,omitempty"` // PEM, client certificate
	Key  string `json:"key,omitempty"`  // PEM, client private key
	// ControlWrap is "tls-auth", "tls-crypt" or "tls-crypt-v2" with its key.
	ControlWrap    string `json:"control_wrap,omitempty"`
	ControlWrapKey string `json:"control_wrap_key,omitempty"`
	KeyDirection   string `json:"key_direction,omitempty"` // "0"/"1" for tls-auth

	Cipher              string   `json:"cipher,omitempty"`
	DataCiphers         []string `json:"data_ciphers,omitempty"`
	DataCiphersFallback string   `json:"data_ciphers_fallback,omitempty"`
	Auth                string   `json:"auth,omitempty"`
	Compression         string   `json:"compression,omitempty"`     // compress <alg>
	CompressionLZO      string   `json:"compression_lzo,omitempty"` // comp-lzo
	RemoteCertTLS       string   `json:"remote_cert_tls,omitempty"`
	VerifyX509Name      string   `json:"verify_x509_name,omitempty"`
	VerifyX509Type      string   `json:"verify_x509_type,omitempty"`
	TLSVersionMin       string   `json:"tls_version_min,omitempty"`
	TLSCipher           string   `json:"tls_cipher,omitempty"`
	MTU                 int      `json:"mtu,omitempty"`
	MSSFix              int      `json:"mss_fix,omitempty"`
	// NeedsAuth is set when the config has auth-user-pass without inline credentials.
	NeedsAuth bool `json:"needs_auth,omitempty"`
}

// OVPNRemote is one `remote host port proto` line.
type OVPNRemote struct {
	Server  string `json:"server"`
	Port    int    `json:"port"`
	Network string `json:"network,omitempty"`
}

// Validate checks the fields every protocol needs.
func (p *Profile) Validate() error {
	if p.Protocol == "" {
		return fmt.Errorf("profile %q: missing protocol", p.Name)
	}
	if p.Protocol == Tor {
		return validateTor(p)
	}
	if p.Protocol == DNSTT {
		return validateDNSTT(p)
	}
	if p.Protocol == Tailscale {
		if p.Password == "" {
			return fmt.Errorf("profile %q: missing auth key", p.Name)
		}
		if o := p.Tailscale; o != nil && o.ControlURL != "" {
			u, err := url.Parse(o.ControlURL)
			if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
				return fmt.Errorf("profile %q: the control server must be an http:// or https:// address", p.Name)
			}
		}
		return nil
	}
	if p.Server == "" {
		return fmt.Errorf("profile %q: missing server", p.Name)
	}
	if p.Port <= 0 || p.Port > 65535 {
		return fmt.Errorf("profile %q: invalid port %d", p.Name, p.Port)
	}
	if err := p.validateMux(); err != nil {
		return err
	}
	if err := p.validateTLSExtras(); err != nil {
		return err
	}
	switch p.Protocol {
	case VLESS, VMess:
		if p.UUID == "" {
			return fmt.Errorf("profile %q: missing uuid", p.Name)
		}
	case Trojan, Hysteria2, AnyTLS:
		if p.Password == "" {
			return fmt.Errorf("profile %q: missing password", p.Name)
		}
	case Shadowsocks:
		if p.Method == "" || p.Password == "" {
			return fmt.Errorf("profile %q: missing method or password", p.Name)
		}
	case TUIC:
		if p.UUID == "" {
			return fmt.Errorf("profile %q: missing uuid", p.Name)
		}
	case Naive:
		if p.Username == "" || p.Password == "" {
			return fmt.Errorf("profile %q: missing naive user or password", p.Name)
		}
	case SSH:
		if p.Username == "" {
			return fmt.Errorf("profile %q: missing ssh user", p.Name)
		}
		if p.Password == "" && (p.SSH == nil || p.SSH.PrivateKey == "") {
			return fmt.Errorf("profile %q: missing ssh password or private key", p.Name)
		}
	case OpenVPN:
		if p.OpenVPN == nil || p.OpenVPN.CA == "" {
			return fmt.Errorf("profile %q: missing OpenVPN CA certificate", p.Name)
		}
	case WireGuard, AmneziaWG:
		if p.WireGuard == nil || p.WireGuard.PrivateKey == "" || p.WireGuard.PeerPublicKey == "" {
			return fmt.Errorf("profile %q: missing wireguard keys", p.Name)
		}
		if len(p.WireGuard.Address) == 0 {
			return fmt.Errorf("profile %q: missing wireguard address", p.Name)
		}
		if via := strings.TrimSpace(p.WireGuard.Via); via != "" {
			scheme, _, _ := strings.Cut(via, "://")
			if p.Protocol == AmneziaWG {
				return fmt.Errorf("profile %q: AmneziaWG cannot be sent through a proxy", p.Name)
			}
			if !slices.Contains(ViaSchemes, strings.ToLower(scheme)) {
				return fmt.Errorf("profile %q: WireGuard can go through a VLESS, VMess, Trojan, Shadowsocks, Hysteria 2 or TUIC link, not %q", p.Name, scheme)
			}
		}
	}
	return nil
}

// tlsTCPProtocols are the protocols whose TLS is the handshake of a TCP connection that fragmenting and ECH apply to.
var tlsTCPProtocols = []string{VLESS, VMess, Trojan, AnyTLS}

func (p *Profile) validateTLSExtras() error {
	tlsOpts := p.TLS
	if tlsOpts == nil {
		return nil
	}
	if (tlsOpts.Fragment || tlsOpts.RecordFragment || tlsOpts.ECH.On()) && !slices.Contains(tlsTCPProtocols, p.Protocol) {
		return fmt.Errorf("profile %q: fragmenting the handshake and ECH are not available for %s", p.Name, p.Protocol)
	}
	if (tlsOpts.Fragment || tlsOpts.RecordFragment) && !tlsOpts.Enabled {
		return fmt.Errorf("profile %q: fragmenting the handshake needs TLS", p.Name)
	}
	if tlsOpts.ECH.On() {
		if !tlsOpts.Enabled {
			return fmt.Errorf("profile %q: ECH needs TLS", p.Name)
		}
		if tlsOpts.Reality != nil {
			return fmt.Errorf("profile %q: ECH cannot be used with Reality", p.Name)
		}
		if c := strings.TrimSpace(tlsOpts.ECH.Config); c != "" && (!strings.HasPrefix(c, echBegin) || !strings.HasSuffix(c, echEnd)) {
			return fmt.Errorf("profile %q: the ECH config must be a %q block", p.Name, "ECH CONFIGS")
		}
	}
	return nil
}

func (p *Profile) validateMux() error {
	mux := p.Multiplex
	if !mux.Enabled() {
		return nil
	}
	switch p.Protocol {
	case VLESS, VMess, Trojan, Shadowsocks:
	default:
		return fmt.Errorf("profile %q: multiplexing is not available for %s", p.Name, p.Protocol)
	}
	if !slices.Contains(MuxProtocols, mux.Protocol) {
		return fmt.Errorf("profile %q: unknown multiplexing protocol %q (use smux, yamux or h2mux)", p.Name, mux.Protocol)
	}
	if mux.MaxConnections < 0 || mux.MinStreams < 0 || mux.MaxStreams < 0 {
		return fmt.Errorf("profile %q: multiplexing numbers cannot be negative", p.Name)
	}
	if mux.MaxStreams > 0 && (mux.MaxConnections > 0 || mux.MinStreams > 0) {
		return fmt.Errorf("profile %q: the most streams cannot be combined with the most connections or the fewest streams", p.Name)
	}
	if p.Protocol == VLESS && p.Flow != "" {
		return fmt.Errorf("profile %q: multiplexing cannot be used with the VLESS flow %q", p.Name, p.Flow)
	}
	return nil
}

// EnsureID assigns a stable ID derived from the connection parameters when none is set.
func (p *Profile) EnsureID() {
	if p.ID != "" {
		return
	}
	key := p.Source
	if key == "" {
		key = fmt.Sprintf("%s|%s|%d|%s|%s", p.Protocol, p.Server, p.Port, p.UUID, p.Password)
		if p.Tor != nil {
			key += fmt.Sprintf("|%s|%q", p.Tor.Builtin, p.Tor.Bridges)
		}
		if p.Tailscale != nil {
			key += fmt.Sprintf("|%s|%s", p.Tailscale.ControlURL, p.Tailscale.Hostname)
		}
		if p.DNSTT != nil {
			key += fmt.Sprintf("|%s|%s|%s", p.DNSTT.Domain, p.DNSTT.PubKey, p.Username)
		}
	}
	sum := sha256.Sum256([]byte(key))
	p.ID = hex.EncodeToString(sum[:6])
}

// AsSlice wraps p in a one-element slice.
func (p *Profile) AsSlice() []*Profile { return []*Profile{p} }

// DisplayName returns Name or a fallback built from server and port.
func (p *Profile) DisplayName() string {
	if p.Name != "" {
		return p.Name
	}
	return fmt.Sprintf("%s:%d", p.Server, p.Port)
}
