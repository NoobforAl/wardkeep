package main

import (
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
)

// levelHelp is the help text of every option that sets the log level.
var levelHelp = "log level: trace, debug, info, warn or error (default: error in release builds, debug otherwise). Warning: " + logs.LevelWarning

func newLogsCmd(global *options) *cobra.Command {
	var (
		lines  int
		follow bool
		level  string
	)
	cmd := &cobra.Command{
		Use:   "logs",
		Short: "Show the server log (what `run` reported: reloads, quota blocks, warnings, errors)",
		Long: `Show the server log: one record per line with its time, level, source and message,
plus the protocol (target), user, error code and error where they apply.
--json prints the records as JSON.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			mgr := global.manager()
			out, err := mgr.LogRecords(manager.LogQuery{Level: level, Limit: lines})
			if err != nil {
				return err
			}
			if global.json && !follow {
				return global.print(out, func() {})
			}
			for _, rec := range out {
				fmt.Println(rec.Text())
			}
			if !follow {
				return nil
			}
			// Follow: print what is new, until Ctrl+C.
			sig := make(chan os.Signal, 1)
			signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
			var last time.Time
			if len(out) > 0 {
				last = out[len(out)-1].Time
			}
			seen := map[string]bool{} // the records at the last time, already printed
			for _, rec := range out {
				if rec.Time.Equal(last) {
					seen[rec.Text()] = true
				}
			}
			tick := time.NewTicker(time.Second)
			defer tick.Stop()
			for {
				select {
				case <-sig:
					return nil
				case <-tick.C:
				}
				current, err := mgr.LogRecords(manager.LogQuery{Level: level, Since: last, Limit: 500})
				if err != nil {
					return err
				}
				for _, rec := range current {
					text := rec.Text()
					if rec.Time.Equal(last) && seen[text] {
						continue
					}
					if !rec.Time.Equal(last) {
						last, seen = rec.Time, map[string]bool{}
					}
					seen[text] = true
					if global.json {
						global.print(rec, func() {})
					} else {
						fmt.Println(text)
					}
				}
			}
		},
	}
	cmd.Flags().IntVarP(&lines, "lines", "n", 100, "how many records to show")
	cmd.Flags().BoolVarP(&follow, "follow", "f", false, "keep printing new records")
	cmd.Flags().StringVarP(&level, "level", "l", "", "show only records at this level or above (trace, debug, info, warn, error, fatal)")
	cmd.AddCommand(newLogLevelCmd(global))
	return cmd
}

func newLogLevelCmd(global *options) *cobra.Command {
	return &cobra.Command{
		Use:       "level [trace|debug|info|warn|error|default]",
		Short:     "Show or set what the server writes to its log (a running server applies it within seconds)",
		Long:      "Show or set the " + levelHelp + ".\n`run --log-level` overrides it for one run.",
		Args:      cobra.MaximumNArgs(1),
		ValidArgs: []string{"trace", "debug", "info", "warn", "error", "default"},
		RunE: func(cmd *cobra.Command, args []string) error {
			mgr := global.manager()
			info, err := mgr.Logging()
			if len(args) == 1 {
				info, err = mgr.SetLogging(manager.LoggingPatch{Level: &args[0]})
			}
			if err != nil {
				return err
			}
			return global.print(info, func() {
				configured := info.Level
				if configured == "" {
					configured = "default"
				}
				fmt.Printf("log level: %s (in use: %s; the default of this build: %s)\n", configured, info.Effective, info.DefaultLevel)
				if lvl, _ := logs.ParseLevel(info.Effective); lvl < logs.LevelInfo {
					fmt.Println("warning: " + logs.LevelWarning)
				}
			})
		},
	}
}

func newAlertsCmd(global *options) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "alerts",
		Short: "Failures nothing handled (a protocol that stopped or did not start, a certificate not renewed, a panic)",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			list, err := global.manager().Alerts()
			if err != nil {
				return err
			}
			return global.print(list, func() {
				if len(list) == 0 {
					fmt.Println("no alerts")
					return
				}
				for _, alert := range list {
					state := "NEW"
					if alert.Acknowledged {
						state = "ok "
					}
					line := fmt.Sprintf("%-4s %s  %s  %-5s %s", alert.ID, state, alert.Last.Local().Format("2006-01-02 15:04"), strings.ToUpper(alert.Level), alert.Msg)
					if alert.Count > 1 {
						line += fmt.Sprintf(" (%d times)", alert.Count)
					}
					if alert.Err != "" {
						line += ": " + alert.Err
					}
					fmt.Println(line)
				}
			})
		},
	}
	var all bool
	ack := &cobra.Command{
		Use:   "ack [id...]",
		Short: "Acknowledge alerts by id, or --all",
		RunE: func(cmd *cobra.Command, args []string) error {
			if all == (len(args) > 0) {
				return fmt.Errorf("%w: name alert ids or use --all", manager.ErrInvalid)
			}
			changed, err := global.manager().AckAlerts(args, all)
			if err != nil {
				return err
			}
			return global.print(map[string]int{"acknowledged": changed}, func() { fmt.Printf("%d alert(s) acknowledged\n", changed) })
		},
	}
	ack.Flags().BoolVar(&all, "all", false, "acknowledge every alert")
	toggle := &cobra.Command{
		Use: "collect <on|off>", Short: "Collect alerts (on by default) or stop", Args: cobra.ExactArgs(1), ValidArgs: []string{"on", "off"},
		RunE: func(cmd *cobra.Command, args []string) error {
			if args[0] != "on" && args[0] != "off" {
				return fmt.Errorf("%w: use on or off", manager.ErrInvalid)
			}
			on := args[0] == "on"
			info, err := global.manager().SetLogging(manager.LoggingPatch{Alerts: &on})
			if err != nil {
				return err
			}
			return global.print(info, func() { fmt.Printf("alerts: %s\n", args[0]) })
		},
	}
	cmd.AddCommand(ack, toggle)
	return cmd
}
