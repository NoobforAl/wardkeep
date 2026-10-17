package main

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/manager"
)

func newDNSCryptCmd(o *options) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "dnscrypt",
		Short: "The optional DNSCrypt resolver for this server's users",
		Long: `The DNSCrypt resolver is a DNS server for this server's users, encrypted and
authenticated with DNSCrypt, so the VPN's DNS is private and under your control.
It is off by default; switch it on with:

  omnitun-server proto enable dnscrypt
  omnitun-server firewall            # opens its port (TCP and UDP, 5443 by default)
  omnitun-server link --stamp        # the DNS stamp (sdns://...) to give to clients

It answers anyone who can reach the port. Leave the port closed to the
internet if only the VPN's users should use it; they reach it through the
tunnel at the server's address.`,
	}
	show := func(info *manager.DNSCryptInfo) {
		state := "off (omnitun-server proto enable dnscrypt)"
		if info.Enabled {
			state = fmt.Sprintf("on, port %d (TCP and UDP)", info.Port)
		}
		up := info.Upstream
		if up == "" {
			up = "the host's resolver (resolv.conf), else 1.1.1.1"
		}
		fmt.Printf("DNSCrypt resolver: %s\nprovider: %s\npublic key: %s\nupstream: %s\n", state, info.ProviderName, info.PublicKey, up)
		if info.Stamp != "" {
			fmt.Printf("stamp: %s\n", info.Stamp)
		}
	}
	status := &cobra.Command{
		Use: "status", Short: "Show the resolver, its key and its stamp", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := o.manager().DNSCrypt()
			if err != nil {
				return err
			}
			return o.print(info, func() { show(info) })
		},
	}
	stamp := &cobra.Command{
		Use: "stamp", Short: "Print the resolver's DNS stamp (same as: link --stamp)", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error { return printDNSCryptStamp(o) },
	}
	rotate := &cobra.Command{
		Use:   "rotate-key",
		Short: "Make a new long-term key; this changes the stamp",
		Long: `Make a new long-term key for the resolver. Its public half is in the stamp, so
the stamp changes and every client must take the new one; restart the server
(omnitun-server run) to use the new key. The short-term keys the certificates
carry are replaced by the running server on its own (every 7 days).`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := o.manager().RotateDNSCryptKey()
			if err != nil {
				return err
			}
			return o.print(info, func() {
				fmt.Println("New key made. Restart the server and give clients the new stamp.")
				show(info)
			})
		},
	}
	upstream := &cobra.Command{
		Use:   "upstream [ip[:port]]",
		Short: "Set the resolver the server asks (no argument: the host's own)",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			addr := ""
			if len(args) == 1 {
				addr = args[0]
			}
			info, err := o.manager().SetDNSCryptUpstream(addr)
			if err != nil {
				return err
			}
			return o.print(info, func() { show(info) })
		},
	}
	cmd.AddCommand(status, stamp, rotate, upstream)
	return cmd
}

// printDNSCryptStamp prints the resolver's stamp (and nothing else, so it can be piped).
func printDNSCryptStamp(o *options) error {
	m := o.manager()
	s, err := m.DNSCryptStamp()
	if err != nil {
		return err
	}
	return o.print(map[string]string{"stamp": s}, func() { fmt.Println(s) })
}
