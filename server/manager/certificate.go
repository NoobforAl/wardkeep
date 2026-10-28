package manager

import (
	"net"
	"regexp"
	"strings"
	"time"

	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/store"
	"github.com/NoobforAl/omnitun/server/tlsfiles"
)

// CertInfo describes where the server's TLS certificate comes from. It never
// contains the DNS provider's secrets.
type CertInfo struct {
	// Mode is "acme" (a real certificate for Domain) or "self-signed".
	Mode   string `json:"mode" enum:"acme,self-signed"`
	Domain string `json:"domain,omitempty"`
	// Status is "issued", "waiting" (ACME is on but the first certificate has
	// not arrived yet; the self-signed one is served meanwhile) or "self-signed".
	Status      string `json:"status" enum:"issued,waiting,self-signed"`
	Provider    string `json:"provider,omitempty"`
	Email       string `json:"email,omitempty"`
	DNSProvider string `json:"dns_provider,omitempty"`
	DNSTokenSet bool   `json:"dns_token_set,omitempty"`
	HTTPPort    int    `json:"http_port,omitempty"`
	// Certificate is the one served right now (by the subscription and API
	// HTTPS endpoints; the protocols use the same files or provider).
	Certificate *tlsfiles.Info `json:"certificate,omitempty"`
	NotAfter    *time.Time     `json:"not_after,omitempty"`
}

var domainName = regexp.MustCompile(`^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$`)

func certInfo(st *store.State, stateStore *store.Store) *CertInfo {
	acme := st.Server.ACME
	info := &CertInfo{Mode: "self-signed", Status: "self-signed"}
	var domain string
	if st.Server.ACMEActive() {
		info.Mode, info.Status, domain = "acme", "waiting", acme.Domain
		info.Domain, info.Provider, info.Email = acme.Domain, acme.Provider, acme.Email
		if info.Provider == "" {
			info.Provider = "letsencrypt"
		}
		info.DNSProvider, info.DNSTokenSet, info.HTTPPort = acme.DNSProvider, acme.DNSToken != "", acme.HTTPPort
	}
	src := tlsfiles.New(serverconf.ACMEDir(stateStore), domain, stateStore.Path(st.Server.CertFile), stateStore.Path(st.Server.KeyFile))
	if c, err := src.Info(); err == nil {
		info.Certificate, info.NotAfter = &c, &c.NotAfter
		if c.Source == "acme" {
			info.Status = "issued"
		}
	}
	return info
}

// Certificate reports the server's certificate setup.
func (m *Manager) Certificate() (*CertInfo, error) {
	st, err := m.Store.Load()
	if err != nil {
		return nil, err
	}
	return certInfo(st, m.Store), nil
}

// ACMEPatch asks for a certificate from an ACME provider. Domain is required
// the first time; other fields keep their value when nil.
type ACMEPatch struct {
	Domain *string `json:"domain,omitempty" doc:"The domain that points at this server"`
	Email  *string `json:"email,omitempty"`
	// Provider is "letsencrypt", "zerossl" or an ACME directory URL.
	Provider *string `json:"provider,omitempty"`
	// DNSProvider is "cloudflare" or "alidns" for the DNS-01 challenge (no
	// open port needed) or "" for HTTP/TLS challenges.
	DNSProvider *string `json:"dns_provider,omitempty" enum:"cloudflare,alidns,"`
	DNSToken    *string `json:"dns_token,omitempty" doc:"Cloudflare API token, or AliDNS access key ID"`
	DNSSecret   *string `json:"dns_secret,omitempty" doc:"AliDNS access key secret"`
	HTTPPort    *int    `json:"http_port,omitempty" doc:"Port for the HTTP-01 challenge if not 80"`
}

// EnableACME switches the server to a real certificate for a domain. The
// domain becomes the server's public address (links use it), so it must
// already point at this machine. The VPN core obtains the certificate when it
// runs, and renews it by itself.
func (m *Manager) EnableACME(patch ACMEPatch) (*CertInfo, error) {
	err := m.Store.Update(func(st *store.State) error {
		acme := st.Server.ACME
		if patch.Domain != nil {
			acme.Domain = strings.ToLower(strings.TrimSpace(*patch.Domain))
		}
		if acme.Domain == "" {
			return invalid("a domain is required")
		}
		if net.ParseIP(acme.Domain) != nil || !domainName.MatchString(acme.Domain) {
			return invalid("%q is not a domain name; certificates cannot be issued for an IP address", acme.Domain)
		}
		if patch.Email != nil {
			acme.Email = strings.TrimSpace(*patch.Email)
		}
		if acme.Email != "" && !strings.Contains(acme.Email, "@") {
			return invalid("%q is not an e-mail address", acme.Email)
		}
		if patch.Provider != nil {
			acme.Provider = *patch.Provider
		}
		switch pr := acme.Provider; {
		case pr == "", pr == "letsencrypt", pr == "zerossl", strings.HasPrefix(pr, "https://"):
		default:
			return invalid("provider must be letsencrypt, zerossl or an https:// ACME directory URL")
		}
		if acme.Provider == "zerossl" && acme.Email == "" {
			return invalid("ZeroSSL needs an e-mail address")
		}
		if patch.DNSProvider != nil {
			acme.DNSProvider = *patch.DNSProvider
		}
		if patch.DNSToken != nil {
			acme.DNSToken = *patch.DNSToken
		}
		if patch.DNSSecret != nil {
			acme.DNSSecret = *patch.DNSSecret
		}
		switch acme.DNSProvider {
		case "":
			acme.DNSToken, acme.DNSSecret = "", ""
		case "cloudflare":
			if acme.DNSToken == "" {
				return invalid("the Cloudflare DNS challenge needs an API token (dns_token)")
			}
		case "alidns":
			if acme.DNSToken == "" || acme.DNSSecret == "" {
				return invalid("the AliDNS challenge needs an access key ID (dns_token) and secret (dns_secret)")
			}
		default:
			return invalid("dns_provider must be cloudflare or alidns")
		}
		if patch.HTTPPort != nil {
			if *patch.HTTPPort < 0 || *patch.HTTPPort > 65535 {
				return invalid("http_port is out of range")
			}
			acme.HTTPPort = *patch.HTTPPort
		}
		acme.Enabled = true
		st.Server.ACME = acme
		// Links must name the domain for the certificate to match; the
		// self-signed certificate (served until the first issuance) too.
		st.Server.PublicHost = acme.Domain
		return store.WriteSelfSignedCert(m.Store.Path(st.Server.CertFile), m.Store.Path(st.Server.KeyFile), acme.Domain)
	})
	if err != nil {
		return nil, err
	}
	return m.Certificate()
}

// UseSelfSigned turns ACME off; the server goes back to its self-signed
// certificate (clients are told to skip verification again).
func (m *Manager) UseSelfSigned() (*CertInfo, error) {
	err := m.Store.Update(func(st *store.State) error {
		st.Server.ACME.Enabled = false
		return nil
	})
	if err != nil {
		return nil, err
	}
	return m.Certificate()
}
