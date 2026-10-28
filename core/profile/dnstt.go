package profile

import (
	"encoding/hex"
	"fmt"
	"net/netip"
	"net/url"
	"strings"
)

// DNSTTOpts configures a DNS tunnel profile (dnstt): a TCP tunnel that travels inside DNS queries, for networks where
// nothing but DNS gets out. Server is the tunnel's domain and Port is 53, so the profile lists like any other.
// Username and Password (Profile.Username/Password) are the SOCKS5 login of the tunnel's upstream, which is how the
// server tells its users apart; both empty means the server is open to anyone with the link.
type DNSTTOpts struct {
	// Domain is the DNS zone delegated to the tunnel server, such as t.example.com.
	Domain string `json:"domain"`
	// PubKey is the server's public key, 64 hex digits.
	PubKey string `json:"pubkey"`
	// Resolvers are tried in order: udp://IP:port, tls://host:port (DoT) or https://host/path (DoH).
	Resolvers []string `json:"resolvers,omitempty"`
}

// DefaultDNSTTResolvers are what a new DNS tunnel profile starts with.
const DefaultDNSTTResolvers = "udp://8.8.8.8:53, udp://1.1.1.1:53, https://dns.google/dns-query"

// dnsttPort is the port a DNS tunnel profile shows (the server's DNS port).
const dnsttPort = 53

func dnsttOf(profile *Profile, create bool) *DNSTTOpts {
	if profile.DNSTT == nil && create {
		profile.DNSTT = &DNSTTOpts{}
	}
	return profile.DNSTT
}

// validDomain reports whether s is a host name: labels of letters, digits and hyphens, 63 bytes at most each.
func validDomain(s string) bool {
	s = strings.TrimSuffix(s, ".")
	if s == "" || len(s) > 253 {
		return false
	}
	for label := range strings.SplitSeq(s, ".") {
		if label == "" || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return false
		}
		for _, r := range label {
			if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-') {
				return false
			}
		}
	}
	return true
}

// CheckDNSTTResolver checks one resolver address: udp://IP:port (an IP address, so no name is looked up outside
// the tunnel), tls://host:port or https://host/path.
func CheckDNSTTResolver(resolver string) error {
	uri, err := url.Parse(strings.TrimSpace(resolver))
	if err != nil || uri.Host == "" {
		return fmt.Errorf("resolver %q is not an address (udp://IP:port, tls://host:port or https://host/path)", resolver)
	}
	switch uri.Scheme {
	case "udp":
		if _, err := netip.ParseAddrPort(uri.Host); err != nil {
			return fmt.Errorf("a UDP resolver must be an IP address and a port, like udp://1.1.1.1:53 (got %q)", resolver)
		}
	case "tls":
		if uri.Port() == "" {
			return fmt.Errorf("a DoT resolver needs a port, like tls://dns.example:853 (got %q)", resolver)
		}
	case "https":
	default:
		return fmt.Errorf("resolver %q: use udp://, tls:// or https://", resolver)
	}
	return nil
}

// validateDNSTT checks a DNS tunnel profile when it is made or edited, so a mistake is reported then and not as a
// failed connection later.
func validateDNSTT(profile *Profile) error {
	opts := profile.DNSTT
	if opts == nil || strings.TrimSpace(opts.Domain) == "" {
		return fmt.Errorf("profile %q: missing tunnel domain", profile.Name)
	}
	if !validDomain(opts.Domain) {
		return fmt.Errorf("profile %q: %q is not a domain name", profile.Name, opts.Domain)
	}
	if k, err := hex.DecodeString(strings.TrimSpace(opts.PubKey)); err != nil || len(k) != 32 {
		return fmt.Errorf("profile %q: the server key must be 64 hexadecimal digits", profile.Name)
	}
	if len(opts.Resolvers) == 0 {
		return fmt.Errorf("profile %q: at least one resolver is needed", profile.Name)
	}
	for _, r := range opts.Resolvers {
		if err := CheckDNSTTResolver(r); err != nil {
			return fmt.Errorf("profile %q: %w", profile.Name, err)
		}
	}
	if (profile.Username == "") != (profile.Password == "") {
		return fmt.Errorf("profile %q: give both a username and a password, or neither", profile.Name)
	}
	return nil
}

// dnsttField is a text field of the DNS tunnel's own settings.
func dnsttStr(sel func(*DNSTTOpts) *string) strPtr {
	return func(p *Profile, create bool) *string {
		if o := dnsttOf(p, create); o != nil {
			return sel(o)
		}
		return nil
	}
}

func dnsttFields() []Field {
	domain := text("dnstt.domain", "Tunnel domain", dnsttStr(func(o *DNSTTOpts) *string { return &o.Domain }), required,
		help("The zone you delegated to the tunnel server, such as t.example.com"))
	set := domain.set
	domain.set = func(profile *Profile, v string) error {
		if err := set(profile, v); err != nil {
			return err
		}
		// The profile is listed by its domain and the DNS port.
		profile.Server, profile.Port = strings.TrimSpace(v), dnsttPort
		return nil
	}
	return []Field{
		domain,
		text("dnstt.pubkey", "Server key", dnsttStr(func(o *DNSTTOpts) *string { return &o.PubKey }), required,
			help("64 hexadecimal digits; the server prints it")),
		list("dnstt.resolvers", "Resolvers", func(p *Profile, c bool) *[]string {
			if o := dnsttOf(p, c); o != nil {
				return &o.Resolvers
			}
			return nil
		}, ", ", def(DefaultDNSTTResolvers), help("Tried in order: udp://IP:port, tls://host:port or https://host/path")),
		username(help("The login of the server's SOCKS5 upstream; empty if it has none")),
		password(),
	}
}
