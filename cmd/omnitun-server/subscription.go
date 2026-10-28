package main

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/manager"
)

func newSubscriptionCmd(global *options) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "subscription",
		Short: "How the subscription is signed, and the order of protocols it asks for",
		Long: `Every subscription answer is signed with the server's key. The public key is in the
subscription link after "#pk=" (omnitun-server link --sub): Wardkeep reads it from there,
and from then on refuses an answer that was changed on the way.

The server can also ask clients to try protocols in an order, for everyone or for one
country (a country where some protocols are blocked). The order is signed with the answer,
so only a client that has the key trusts it:

  omnitun-server subscription order vless,hysteria2,trojan
  omnitun-server subscription order --country IR hysteria2,vless
  omnitun-server subscription order --country IR        # clear the order of one country`,
	}
	show := func(info *manager.SubscriptionInfo) {
		fmt.Printf("signing key (public): %s\n", info.PublicKey)
		if len(info.ProtocolOrder) == 0 {
			fmt.Println("protocol order: not set (clients choose)")
			return
		}
		for _, k := range info.OrderKeys() {
			who := "everyone"
			if k != "" {
				who = k
			}
			fmt.Printf("protocol order for %s: %s\n", who, info.ProtocolOrder[k])
		}
	}
	status := &cobra.Command{
		Use: "status", Short: "Show the public signing key and the protocol order", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := global.manager().Subscription()
			if err != nil {
				return err
			}
			return global.print(info, func() { show(info) })
		},
	}
	var country string
	order := &cobra.Command{
		Use:   "order [--country XX] [protocol,protocol,...]",
		Short: "Ask clients to try protocols in this order (no list: clear it)",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			list := ""
			if len(args) == 1 {
				list = args[0]
			}
			info, err := global.manager().SetProtocolOrder(country, list)
			if err != nil {
				return err
			}
			return global.print(info, func() { show(info) })
		},
	}
	order.Flags().StringVar(&country, "country", "", "a two-letter country code; without it, the order is for everyone")
	rotate := &cobra.Command{
		Use:   "rotate-key",
		Short: "Make a new signing key; users need the new subscription link",
		Long: `Make a new signing key. The public key is in the subscription link, so every user must
take the new link; until they do, clients with the old key refuse the subscription.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info, err := global.manager().RotateSigningKey()
			if err != nil {
				return err
			}
			return global.print(info, func() {
				fmt.Println("New key made. Give every user the new subscription link (omnitun-server link --sub).")
				show(info)
			})
		},
	}
	cmd.AddCommand(status, order, rotate)
	return cmd
}
