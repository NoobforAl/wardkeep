package importer

import (
	"errors"
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// hysteria://host:port?protocol=udp&auth=..&peer=sni&insecure=1&upmbps=10&downmbps=50&alpn=hysteria&obfsParam=..#name
func parseHysteria(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	prof := &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.Hysteria,
		Server:   host,
		Port:     port,
		Password: firstNonEmpty(query.Get("auth"), query.Get("auth_str"), uri.User.Username()),
		TLS: &profile.TLS{
			Enabled:    true,
			ServerName: firstNonEmpty(query.Get("peer"), query.Get("sni")),
			Insecure:   truthy(query.Get("insecure")) || truthy(query.Get("allowInsecure")),
			ALPN:       splitList(query.Get("alpn")),
		},
	}
	hy2 := &profile.Hy2{Obfs: firstNonEmpty(query.Get("obfsParam"), query.Get("obfs-password"))}
	if query.Get("obfs") != "" && query.Get("obfs") != "xplus" && hy2.Obfs == "" {
		hy2.Obfs = query.Get("obfs")
	}
	hy2.UpMbps, _ = strconv.Atoi(firstNonEmpty(query.Get("upmbps"), query.Get("up")))
	hy2.DownMbps, _ = strconv.Atoi(firstNonEmpty(query.Get("downmbps"), query.Get("down")))
	prof.Hysteria2 = hy2
	return prof, nil
}

// anytls://password@host:port/?sni=..&insecure=1&fp=chrome#name
func parseAnyTLS(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	password, _ := url.PathUnescape(uri.User.Username())
	tlsOpts := &profile.TLS{
		Enabled:     true,
		ServerName:  firstNonEmpty(query.Get("sni"), query.Get("peer")),
		Insecure:    truthy(query.Get("insecure")) || truthy(query.Get("allowInsecure")),
		ALPN:        splitList(query.Get("alpn")),
		Fingerprint: query.Get("fp"),
	}
	tlsExtrasFrom(tlsOpts, query.Get)
	return &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.AnyTLS,
		Server:   host,
		Port:     port,
		Password: password,
		TLS:      tlsOpts,
	}, nil
}

// ssh://user:password@host:port?pk=<PEM private key>&pkp=<passphrase>&hk=<host key>,<host key>#name
// (the format used by sing-box based clients such as Hiddify).
func parseSSH(link string) (*profile.Profile, error) {
	uri, host, port, err := parseURL(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	password, _ := uri.User.Password()
	opts := &profile.SSHOpts{
		PrivateKey:           firstNonEmpty(query.Get("pk"), query.Get("private_key")),
		PrivateKeyPassphrase: firstNonEmpty(query.Get("pkp"), query.Get("private_key_passphrase")),
		HostKey:              splitList(firstNonEmpty(query.Get("hk"), query.Get("host_key"))),
		ClientVersion:        query.Get("client_version"),
	}
	prof := &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.SSH,
		Server:   host,
		Port:     port,
		Username: uri.User.Username(),
		Password: password,
	}
	if opts.PrivateKey != "" || len(opts.HostKey) > 0 || opts.ClientVersion != "" {
		prof.SSH = opts
	}
	return prof, nil
}

// naive+https://user:pass@host:port/?extra-headers=K%3AV%0D%0AK2%3AV2#name  (naive+quic:// for HTTP/3)
func parseNaive(link string) (*profile.Profile, error) {
	quic := strings.HasPrefix(strings.ToLower(link), "naive+quic://")
	_, rest, _ := strings.Cut(link, "://")
	uri, host, port, err := parseURL("https://" + rest)
	if err != nil {
		if !strings.Contains(err.Error(), "invalid port") {
			return nil, err
		}
		// The port is optional (default 443).
		uri, err = url.Parse("https://" + rest)
		if err != nil {
			return nil, err
		}
		host, port = uri.Hostname(), 443
	}
	password, _ := uri.User.Password()
	prof := &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.Naive,
		Server:   host,
		Port:     port,
		Username: uri.User.Username(),
		Password: password,
		TLS:      &profile.TLS{Enabled: true, ServerName: uri.Query().Get("sni")},
	}
	opts := &profile.NaiveOpts{QUIC: quic}
	if h := uri.Query().Get("extra-headers"); h != "" {
		opts.ExtraHeaders = map[string]string{}
		for line := range strings.SplitSeq(strings.ReplaceAll(h, "\r\n", "\n"), "\n") {
			if k, v, ok := strings.Cut(line, ":"); ok {
				opts.ExtraHeaders[strings.TrimSpace(k)] = strings.TrimSpace(v)
			}
		}
	}
	if opts.QUIC || len(opts.ExtraHeaders) > 0 {
		prof.Naive = opts
	}
	return prof, nil
}

// ikev2://[user:password@]host[:port]?auth=eap|psk|cert&psk=..&remote_id=..&local_id=..&ca=<PEM>&tcp=1&system=1#name
// tcp=1 carries IKE/ESP over TCP (RFC 8229, port = the TCP port); system=1
// uses the OS's IKEv2 client instead of the built-in one.
func parseIKEv2(link string) (*profile.Profile, error) {
	uri, err := url.Parse(link)
	if err != nil {
		return nil, err
	}
	if uri.Hostname() == "" {
		return nil, errMissingServer
	}
	query := uri.Query()
	port := 500
	if v := uri.Port(); v != "" {
		if port, err = strconv.Atoi(v); err != nil {
			return nil, err
		}
	}
	password, _ := uri.User.Password()
	opts := &profile.IKEv2Opts{
		Auth:     strings.ToLower(query.Get("auth")),
		PSK:      query.Get("psk"),
		LocalID:  query.Get("local_id"),
		RemoteID: query.Get("remote_id"),
		CACert:   query.Get("ca"),
		TCP:      truthy(query.Get("tcp")),
		System:   truthy(query.Get("system")),
	}
	opts.MTU, _ = strconv.Atoi(query.Get("mtu"))
	if opts.Auth == "" {
		opts.Auth = "eap"
		if opts.PSK != "" {
			opts.Auth = "psk"
		}
	}
	return &profile.Profile{
		Name: fragmentName(uri), Protocol: profile.IKEv2, Server: uri.Hostname(), Port: port,
		Username: uri.User.Username(), Password: password, IKEv2: opts,
	}, nil
}

var errMissingServer = errors.New("missing server address")

// sstp://user:password@host[:port]?insecure=1#name  (port 443 by default)
func parseSSTP(link string) (*profile.Profile, error) {
	uri, err := url.Parse(link)
	if err != nil {
		return nil, err
	}
	if uri.Hostname() == "" {
		return nil, errMissingServer
	}
	port := 443
	if v := uri.Port(); v != "" {
		if port, err = strconv.Atoi(v); err != nil {
			return nil, err
		}
	}
	password, _ := uri.User.Password()
	query := uri.Query()
	return &profile.Profile{
		Name: fragmentName(uri), Protocol: profile.SSTP, Server: uri.Hostname(), Port: port,
		Username: uri.User.Username(), Password: password,
		// SSTP servers mostly use self-signed certificates; MS-CHAPv2 still
		// authenticates the server (it must know the password).
		TLS: &profile.TLS{Enabled: true, Insecure: query.Get("insecure") != "0"},
	}, nil
}

// dnstt://<server key>@<domain>?resolver=udp://1.1.1.1:53&resolver=https://dns.google/dns-query&user=u&pass=p#name
// The resolver parameter may repeat or hold a comma-separated list; without one the profile starts with the usual
// public resolvers.
func parseDNSTT(link string) (*profile.Profile, error) {
	uri, err := url.Parse(link)
	if err != nil {
		return nil, fmt.Errorf("invalid link: %w", err)
	}
	domain := uri.Hostname()
	if domain == "" {
		return nil, fmt.Errorf("missing tunnel domain")
	}
	key, _ := url.PathUnescape(uri.User.Username())
	query := uri.Query()
	var resolvers []string
	for _, v := range query["resolver"] {
		resolvers = append(resolvers, splitList(v)...)
	}
	if len(resolvers) == 0 {
		resolvers = splitList(profile.DefaultDNSTTResolvers)
	}
	return &profile.Profile{
		Name:     fragmentName(uri),
		Protocol: profile.DNSTT,
		Server:   domain,
		Port:     53,
		Username: query.Get("user"),
		Password: query.Get("pass"),
		DNSTT:    &profile.DNSTTOpts{Domain: domain, PubKey: strings.TrimSpace(key), Resolvers: resolvers},
	}, nil
}
