package main

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/manager"
)

func newDNSTTCmd(global *options) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "dnstt",
		Short: "The optional DNS tunnel, for users on networks where only DNS gets out",
		Long: `The DNS tunnel carries a user's connections inside DNS queries. It works where nothing else
does (a network that lets DNS through and blocks the rest), but it is slow, TCP only, and the
volume of DNS queries is visible to whoever watches the network. Use it as a last resort.

It needs a domain whose DNS you control, with a zone delegated to this server:

  omnitun-server dnstt domain t.example.com    # says which DNS records to create
  omnitun-server proto enable dnstt            # serves UDP port 53 (open it in the firewall)
  omnitun-server link <user>                   # the user's link carries the domain and the key

Port 53 must be free: on Ubuntu, systemd-resolved listens on 127.0.0.53:53 and may need
DNSStubListener=no in /etc/systemd/resolved.conf. Users log in to the tunnel with the same
credentials as everywhere else, so quotas and the user list work as for the other protocols.`,
	}
	show := func(info *manager.DNSTTInfo) {
		state := "off (omnitun-server proto enable dnstt)"
		if info.Enabled {
			state = fmt.Sprintf("on, UDP port %d", info.Port)
		}
		domain := info.Domain
		if domain == "" {
			domain = "not set (omnitun-server dnstt domain <name>)"
		}
		fmt.Printf("DNS tunnel: %s\ndomain: %s\nserver key: %s\n", state, domain, info.PublicKey)
		if len(info.Records) > 0 {
			fmt.Println("\nCreate these DNS records at the provider of the domain:")
			for _, r := range info.Records {
				fmt.Printf("  %-32s %-5s %s\n", r.Name, r.Type, r.Value)
			}
			fmt.Println("\nCheck it with: dig NS " + info.Domain + " (it must name this server), and open UDP port 53.")
		}
	}
	status := &cobra.Command{
		Use: "status", Short: "Show the DNS tunnel, its key and the DNS records it needs", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := global.manager().DNSTT()
			if err != nil {
				return err
			}
			return global.print(info, func() { show(info) })
		},
	}
	domain := &cobra.Command{
		Use:   "domain <name>",
		Short: "Set the DNS zone delegated to this server (such as t.example.com)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := global.manager().SetDNSTTDomain(args[0])
			if err != nil {
				return err
			}
			return global.print(info, func() { show(info) })
		},
	}
	rotate := &cobra.Command{
		Use:   "rotate-key",
		Short: "Make a new server key; every user needs a new link",
		Long: `Make a new key pair for the tunnel. The public key is in every user's link, so every user
must take the new link; until they do, the tunnel does not connect for them. Restart the server
(omnitun-server run) to use it.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := global.manager().RotateDNSTTKey()
			if err != nil {
				return err
			}
			return global.print(info, func() {
				fmt.Println("New key made. Restart the server and give every user their new link.")
				show(info)
			})
		},
	}
	cmd.AddCommand(status, domain, rotate)
	return cmd
}
