package importer

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// looksLikeOVPN reports whether text is an OpenVPN client config.
func looksLikeOVPN(text string) bool {
	hasRemote, hasClientish := false, false
	for line := range strings.SplitSeq(text, "\n") {
		f := strings.Fields(line)
		if len(f) == 0 {
			continue
		}
		switch strings.ToLower(f[0]) {
		case "remote":
			hasRemote = true
		case "client", "dev", "<ca>", "proto", "tls-client", "pull":
			hasClientish = true
		}
	}
	return hasRemote && hasClientish
}

// ParseOVPN parses a single-file OpenVPN client config (certificates inline).
// Client-side tuning directives that don't change the connection are ignored.
func ParseOVPN(text string) (*profile.Profile, error) {
	opts := &profile.OVPN{}
	prof := &profile.Profile{Protocol: profile.OpenVPN, OpenVPN: opts, Source: text}
	defaultPort, defaultProto := 1194, "udp"
	type remote struct {
		host  string
		port  int
		proto string
	}
	var remotes []remote
	var unsupported []string

	lines := strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n")
	for i := 0; i < len(lines); i++ {
		line := strings.TrimSpace(lines[i])
		if line == "" || line[0] == '#' || line[0] == ';' {
			continue
		}
		// Inline blocks: <ca> ... </ca>
		if strings.HasPrefix(line, "<") && strings.HasSuffix(line, ">") && !strings.HasPrefix(line, "</") {
			tag := strings.Trim(line, "<>")
			var body []string
			for i++; i < len(lines) && strings.TrimSpace(lines[i]) != "</"+tag+">"; i++ {
				body = append(body, lines[i])
			}
			if i >= len(lines) {
				return nil, fmt.Errorf("unterminated <%s> block", tag)
			}
			content := strings.TrimSpace(strings.Join(body, "\n"))
			switch tag {
			case "ca":
				opts.CA = content
			case "cert":
				opts.Cert = content
			case "key":
				opts.Key = content
			case "tls-auth", "tls-crypt", "tls-crypt-v2":
				opts.ControlWrap, opts.ControlWrapKey = tag, content
			case "auth-user-pass":
				creds := strings.SplitN(content, "\n", 2)
				if len(creds) == 2 {
					prof.Username, prof.Password = strings.TrimSpace(creds[0]), strings.TrimSpace(creds[1])
				}
			case "pkcs12", "secret", "http-proxy-user-pass":
				unsupported = append(unsupported, "<"+tag+">")
			}
			continue
		}

		fields := strings.Fields(line)
		arg := func(n int) string {
			if n < len(fields) {
				return strings.Trim(fields[n], `"`)
			}
			return ""
		}
		switch dir := strings.ToLower(fields[0]); dir {
		case "remote":
			rem := remote{host: arg(1), port: -1, proto: arg(3)}
			if v := arg(2); v != "" {
				n, err := strconv.Atoi(v)
				if err != nil || n <= 0 || n > 65535 {
					return nil, fmt.Errorf("invalid remote port %q", v)
				}
				rem.port = n
			}
			remotes = append(remotes, rem)
		case "port", "rport":
			if n, err := strconv.Atoi(arg(1)); err == nil {
				defaultPort = n
			}
		case "proto":
			defaultProto = arg(1)
		case "dev":
			if strings.HasPrefix(arg(1), "tap") {
				return nil, fmt.Errorf("TAP (layer 2) OpenVPN configs are not supported, only TUN")
			}
		case "remote-random":
			opts.RemoteRandom = true
		case "cipher":
			opts.Cipher = arg(1)
		case "data-ciphers", "ncp-ciphers":
			opts.DataCiphers = strings.Split(arg(1), ":")
		case "data-ciphers-fallback":
			opts.DataCiphersFallback = arg(1)
		case "auth":
			opts.Auth = arg(1)
		case "comp-lzo":
			opts.CompressionLZO = orDefault(arg(1), "adaptive")
		case "compress":
			opts.Compression = orDefault(arg(1), "stub")
		case "remote-cert-tls":
			opts.RemoteCertTLS = arg(1)
		case "verify-x509-name":
			opts.VerifyX509Name, opts.VerifyX509Type = arg(1), arg(2)
		case "tls-version-min":
			opts.TLSVersionMin = arg(1)
		case "tls-cipher":
			opts.TLSCipher = arg(1)
		case "key-direction":
			opts.KeyDirection = arg(1)
		case "tun-mtu":
			opts.MTU, _ = strconv.Atoi(arg(1))
		case "mssfix":
			opts.MSSFix, _ = strconv.Atoi(arg(1))
		case "auth-user-pass":
			if arg(1) != "" {
				return nil, fmt.Errorf("auth-user-pass refers to the file %q; enter the username and password in the app instead", arg(1))
			}
			opts.NeedsAuth = true
		case "tls-auth", "tls-crypt", "tls-crypt-v2":
			if arg(1) != "" && arg(1) != "[inline]" {
				return nil, fmt.Errorf("%s refers to the file %q; use a single-file .ovpn with the key inline", dir, arg(1))
			}
			if dir == "tls-auth" && arg(2) != "" {
				opts.KeyDirection = arg(2)
			}
		case "ca", "cert", "key", "pkcs12":
			if arg(1) != "[inline]" {
				return nil, fmt.Errorf("%s refers to the file %q; use a single-file .ovpn with certificates inline", dir, arg(1))
			}
		case "secret":
			return nil, fmt.Errorf("static-key OpenVPN configs are not supported")
		case "http-proxy", "socks-proxy":
			unsupported = append(unsupported, dir)
		}
	}
	if len(unsupported) > 0 {
		return nil, fmt.Errorf("unsupported OpenVPN options: %s", strings.Join(unsupported, ", "))
	}
	if len(remotes) == 0 {
		return nil, fmt.Errorf("no remote server")
	}
	if opts.CA == "" {
		return nil, fmt.Errorf("no <ca> certificate")
	}
	if (opts.Cert == "") != (opts.Key == "") {
		return nil, fmt.Errorf("client certificate and key must both be present")
	}
	if opts.Cert == "" && !opts.NeedsAuth && prof.Username == "" {
		return nil, fmt.Errorf("no client certificate and no auth-user-pass")
	}
	if prof.Username != "" {
		opts.NeedsAuth = true // inline credentials were given
	}
	for i, rem := range remotes {
		if rem.port < 0 {
			rem.port = defaultPort
		}
		proto, err := ovpnNetwork(orDefault(rem.proto, defaultProto))
		if err != nil {
			return nil, err
		}
		if i == 0 {
			prof.Server, prof.Port, opts.Network = rem.host, rem.port, proto
			continue
		}
		opts.Remotes = append(opts.Remotes, profile.OVPNRemote{Server: rem.host, Port: rem.port, Network: proto})
	}
	prof.Name = "OpenVPN " + prof.Server
	if err := prof.Validate(); err != nil {
		return nil, err
	}
	prof.EnsureID()
	return prof, nil
}

func ovpnNetwork(proto string) (string, error) {
	switch strings.ToLower(proto) {
	case "", "udp", "udp4", "udp6":
		return "udp", nil
	case "tcp", "tcp-client", "tcp4", "tcp6", "tcp4-client", "tcp6-client":
		return "tcp", nil
	}
	return "", fmt.Errorf("unsupported proto %q", proto)
}

func orDefault(s, def string) string {
	if s == "" {
		return def
	}
	return s
}
