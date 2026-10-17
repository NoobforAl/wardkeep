package main

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/manager"
)

func newDNSCryptCmd(o *options) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "dnscrypt",
		Short: "The optional DNSCrypt resolver for this server's users",
		Long: `The DNSCrypt resolver is a DNS server for this server's users, encrypted and
authenticated with DNSCrypt, so the VPN's DNS is private and under your control.
It is off by default, and it never listens on every interface: name the one
address first (the server's side of the tunnel the users are in, e.g. 10.30.0.1
for WireGuard, 10.31.0.1 for AmneziaWG; or 127.0.0.1), then switch it on:

  omnitun-server dnscrypt listen 10.30.0.1
  omnitun-server proto enable dnscrypt
  omnitun-server link --stamp        # the DNS stamp (sdns://...) to give to clients

It answers only the VPN's clients (the tunnel networks), the server itself and
ranges you add with 'dnscrypt allow'; everything else is dropped. It asks the
public resolver 1.1.1.1 unless you choose another ('dnscrypt upstream'); the
host's own resolver only if you say 'dnscrypt upstream system'. Keep the port
closed to the internet in the firewall: users reach it through the tunnel.`,
	}
	show := func(info *manager.DNSCryptInfo) {
		state := "off (omnitun-server proto enable dnscrypt)"
		if info.Enabled {
			state = fmt.Sprintf("on, port %d (TCP and UDP)", info.Port)
		}
		up := info.Upstream
		switch up {
		case "":
			up = "1.1.1.1 (public)"
		case "system":
			up = "the host's resolver (resolv.conf)"
		}
		listen := info.Listen
		if listen == "" {
			listen = "not set (omnitun-server dnscrypt listen <ip>)"
		}
		allow := "VPN clients, loopback, this server"
		if len(info.Allow) > 0 {
			allow += " + " + strings.Join(info.Allow, ", ")
		}
		fmt.Printf("DNSCrypt resolver: %s\nlistens on: %s\nanswers: %s\nprovider: %s\npublic key: %s\nupstream: %s\n", state, listen, allow, info.ProviderName, info.PublicKey, up)
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
		Use:   "upstream [ip[:port]|system]",
		Short: "Set the resolver the server asks (no argument: the public 1.1.1.1; system: the host's own)",
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
	listen := &cobra.Command{
		Use:   "listen <ip>",
		Short: "Set the one address the resolver listens on (a VPN tunnel address or 127.0.0.1)",
		Long: `Set the address the resolver listens on. It must be a specific address, never
0.0.0.0 or ::. Use the server's side of the tunnel the users are in (10.30.0.1
for WireGuard, 10.31.0.1 for AmneziaWG, 10.18.0.1 or 10.19.0.1 for OpenVPN) so
only tunnel users can reach it; the stamp names this address. The address has to
exist when the server starts, so the tunnel's interface must be up.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := o.manager().SetDNSCryptListen(args[0])
			if err != nil {
				return err
			}
			return o.print(info, func() { show(info) })
		},
	}
	allow := &cobra.Command{
		Use:   "allow [cidr...]",
		Short: "Allow more source ranges to query (no argument: clear them)",
		Long: `Allow extra source ranges (CIDRs or single IPs) to query the resolver, besides
loopback, this server's own addresses and the VPN client networks. Replaces the
earlier list; with no argument it is emptied. A range of every address is refused.`,
		Args: cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := o.manager().SetDNSCryptAllow(args)
			if err != nil {
				return err
			}
			return o.print(info, func() { show(info) })
		},
	}
	cmd.AddCommand(status, stamp, listen, allow, rotate, upstream)
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
