package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/manager"
	"github.com/NoobforAl/omnitun/server/store"
)

func newStatusCmd(global *options) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show the server summary",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := global.manager().Server()
			if err != nil {
				return err
			}
			return global.print(info, func() {
				fmt.Printf("%s (%s)\n", info.Name, info.PublicHost)
				fmt.Printf("users: %d (%d active)   protocols enabled: %d\n", info.Users, info.ActiveUsers, info.Protocols)
				if info.Running {
					fmt.Printf("server: running, %d connection(s) now\n", info.Connections)
				} else {
					fmt.Println("server: not running (start it with: omnitun-server run)")
				}
				if info.SubscriptionPort > 0 {
					fmt.Printf("subscriptions on port %d\n", info.SubscriptionPort)
				}
			})
		},
	}
}

func printProtocols(list []manager.ProtocolInfo, subPort int) {
	tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "PROTOCOL\tNAME\tPORT\tTRANSPORT\tSTATUS\tTRAFFIC (MONTH)\tCONN")
	for _, proto := range list {
		status := "disabled"
		if proto.Enabled {
			status = "enabled"
		}
		conn := "-"
		if proto.Connections > 0 {
			conn = fmt.Sprint(proto.Connections)
		}
		name := proto.Name
		if proto.AmneziaWGVersion != "" {
			name += " " + proto.AmneziaWGVersion
		}
		fmt.Fprintf(tw, "%s\t%s\t%d\t%s\t%s\t%s\t%s\n", proto.Key, name, proto.Port, proto.Transport, status, humanBytes(proto.MonthBytes), conn)
	}
	if subPort > 0 {
		fmt.Fprintf(tw, "subscriptions\t\t%d\ttcp\thttp\t\t\n", subPort)
	}
	tw.Flush()
}

func newProtoCmd(global *options) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "proto",
		Short: "List protocols, switch them on or off, change ports",
	}
	keys := strings.Join(store.AllProtocols, ", ")

	list := &cobra.Command{
		Use:   "list",
		Short: "Protocols, ports and status",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			mgr := global.manager()
			protos, err := mgr.Protocols()
			if err != nil {
				return err
			}
			info, _ := mgr.Server()
			return global.print(protos, func() { printProtocols(protos, info.SubscriptionPort) })
		},
	}
	setEnabled := func(use string, on bool) *cobra.Command {
		return &cobra.Command{
			Use:       use + " <protocol>",
			Short:     strings.ToUpper(use[:1]) + use[1:] + " a protocol (" + keys + ")",
			Args:      cobra.ExactArgs(1),
			ValidArgs: store.AllProtocols,
			RunE: func(cmd *cobra.Command, args []string) error {
				p, err := global.manager().SetProtocol(args[0], manager.ProtocolPatch{Enabled: &on})
				if err != nil {
					return err
				}
				return global.print(p, func() { fmt.Printf("%s: enabled=%v port=%d\n", p.Key, p.Enabled, p.Port) })
			},
		}
	}
	port := &cobra.Command{
		Use:       "port <protocol> <port>",
		Short:     "Change a protocol's port",
		Args:      cobra.ExactArgs(2),
		ValidArgs: store.AllProtocols,
		RunE: func(cmd *cobra.Command, args []string) error {
			n, err := strconv.Atoi(args[1])
			if err != nil {
				return fmt.Errorf("%w: port %q is not a number", manager.ErrInvalid, args[1])
			}
			p, err := global.manager().SetProtocol(args[0], manager.ProtocolPatch{Port: &n})
			if err != nil {
				return err
			}
			return global.print(p, func() { fmt.Printf("%s: enabled=%v port=%d\n", p.Key, p.Enabled, p.Port) })
		},
	}
	awgVersion := &cobra.Command{
		Use:   "awg-version <2.0|1.x>",
		Short: "Make new AmneziaWG obfuscation parameters of version 2.0 (default) or classic 1.x",
		Long: `Make new AmneziaWG obfuscation parameters of the given version.

2.0 draws every packet's header from a range and pads more packets, which is
harder to recognise; use 1.x ("classic") only for clients that never got 2.0.
Every user's AmneziaWG config and link changes, so their devices must import
it again. The version the server already has is left alone.`,
		Args:      cobra.ExactArgs(1),
		ValidArgs: []string{store.AWG2, store.AWGClassic},
		RunE: func(cmd *cobra.Command, args []string) error {
			v, err := store.ParseAWGVersion(args[0])
			if err != nil {
				return fmt.Errorf("%w: %v", manager.ErrInvalid, err)
			}
			p, err := global.manager().SetProtocol(store.AmneziaWGKey, manager.ProtocolPatch{AmneziaWGVersion: &v})
			if err != nil {
				return err
			}
			return global.print(p, func() {
				fmt.Printf("%s: AmneziaWG %s (users must import their AmneziaWG config or link again)\n", p.Key, p.AmneziaWGVersion)
			})
		},
	}
	ipv6 := &cobra.Command{
		Use:   "ipv6 <on|off>",
		Short: "Give users an IPv6 address inside WireGuard, AmneziaWG, OpenVPN and IKEv2 tunnels",
		Long: `Give users an IPv6 address inside the tunnels that can carry one (WireGuard,
AmneziaWG, OpenVPN, IKEv2/IPsec; SSTP cannot), and route and NAT it on this host.

Turn it on only if this host has IPv6 to the internet and forwards it
(sysctl net.ipv6.conf.all.forwarding=1): otherwise apps would try IPv6
addresses that go nowhere. Users' configs and links change (an extra address),
so their devices import them again.`,
		Args:      cobra.ExactArgs(1),
		ValidArgs: []string{"on", "off"},
		RunE: func(cmd *cobra.Command, args []string) error {
			var on bool
			switch args[0] {
			case "on":
				on = true
			case "off":
			default:
				return fmt.Errorf("%w: say on or off", manager.ErrInvalid)
			}
			info, err := global.manager().SetIPv6(on)
			if err != nil {
				return err
			}
			return global.print(info, func() { fmt.Println("IPv6 in the tunnels:", map[bool]string{true: "on", false: "off"}[info.IPv6]) })
		},
	}
	cmd.AddCommand(list, setEnabled("enable", true), setEnabled("disable", false), port, awgVersion, ipv6)
	return cmd
}
