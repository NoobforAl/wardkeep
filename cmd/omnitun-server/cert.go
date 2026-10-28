package main

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/manager"
)

func printCert(cert *manager.CertInfo) func() {
	return func() {
		switch cert.Mode {
		case "acme":
			fmt.Printf("certificate: Let's Encrypt-style (ACME) for %s via %s\n", cert.Domain, cert.Provider)
			if cert.DNSProvider != "" {
				fmt.Printf("challenge:   DNS-01 through %s\n", cert.DNSProvider)
			} else if cert.HTTPPort != 0 {
				fmt.Printf("challenge:   HTTP-01 on port %d (or TLS-ALPN on 443)\n", cert.HTTPPort)
			} else {
				fmt.Println("challenge:   HTTP-01 on port 80 or TLS-ALPN-01 on port 443")
			}
			switch cert.Status {
			case "issued":
				fmt.Printf("status:      issued, valid until %s\n", cert.NotAfter.Local().Format("2006-01-02"))
			default:
				fmt.Println("status:      waiting for the first certificate; the self-signed one is served meanwhile")
				fmt.Println("             (the server must be running, the domain must point here and the challenge port must be reachable)")
			}
		default:
			fmt.Println("certificate: self-signed (clients are told to skip verification)")
			if cert.NotAfter != nil {
				fmt.Printf("valid until: %s (renewed automatically on start)\n", cert.NotAfter.Local().Format("2006-01-02"))
			}
		}
	}
}

func newCertCmd(global *options) *cobra.Command {
	cmd := &cobra.Command{Use: "cert", Short: "TLS certificate: self-signed or a real one from an ACME provider"}

	status := &cobra.Command{
		Use: "status", Short: "Show where the certificate comes from and when it expires", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			cert, err := global.manager().Certificate()
			if err != nil {
				return err
			}
			return global.print(cert, printCert(cert))
		},
	}

	var (
		domain, email, provider, dns, dnsToken, dnsSecret string
		httpPort                                          int
	)
	acme := &cobra.Command{
		Use:   "acme --domain vpn.example.com",
		Short: "Get a real certificate (Let's Encrypt by default) for a domain",
		Long: `Switches the server to a real certificate for a domain, so clients verify it
normally (no insecure=1) and NaiveProxy needs no pinning. The domain becomes the
server's public address, so it must already point at this machine.

The VPN core obtains the certificate when it runs and renews it by itself. It
needs one of: port 80 free (HTTP-01), port 443 free (TLS-ALPN-01), or a DNS
provider token (--dns cloudflare|alidns) which needs no open port at all.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			patch := manager.ACMEPatch{}
			fl := cmd.Flags()
			if fl.Changed("domain") {
				patch.Domain = &domain
			}
			if fl.Changed("email") {
				patch.Email = &email
			}
			if fl.Changed("provider") {
				patch.Provider = &provider
			}
			if fl.Changed("dns") {
				patch.DNSProvider = &dns
			}
			if fl.Changed("dns-token") {
				patch.DNSToken = &dnsToken
			}
			if fl.Changed("dns-secret") {
				patch.DNSSecret = &dnsSecret
			}
			if fl.Changed("http-port") {
				patch.HTTPPort = &httpPort
			}
			cert, err := global.manager().EnableACME(patch)
			if err != nil {
				return err
			}
			return global.print(cert, func() {
				printCert(cert)()
				fmt.Printf("\nThe server address is now %s. Existing users' links changed: show them with: omnitun-server link <name>\n", cert.Domain)
			})
		},
	}
	flags := acme.Flags()
	flags.StringVar(&domain, "domain", "", "the domain that points at this server")
	flags.StringVar(&email, "email", "", "contact address for the certificate authority (recommended)")
	flags.StringVar(&provider, "provider", "", "letsencrypt (default), zerossl or an ACME directory URL")
	flags.StringVar(&dns, "dns", "", "use the DNS-01 challenge through cloudflare or alidns")
	flags.StringVar(&dnsToken, "dns-token", "", "Cloudflare API token, or AliDNS access key ID")
	flags.StringVar(&dnsSecret, "dns-secret", "", "AliDNS access key secret")
	flags.IntVar(&httpPort, "http-port", 0, "port for the HTTP-01 challenge if not 80")

	self := &cobra.Command{
		Use: "self-signed", Short: "Go back to the self-signed certificate", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			cert, err := global.manager().UseSelfSigned()
			if err != nil {
				return err
			}
			return global.print(cert, printCert(cert))
		},
	}
	cmd.AddCommand(status, acme, self)
	return cmd
}
