package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/NoobforAl/omnitun/core/pprofsrv"
	"github.com/NoobforAl/omnitun/server/api"
	"github.com/NoobforAl/omnitun/server/install"
	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
	"github.com/NoobforAl/omnitun/server/runtime"
	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/store"
	"github.com/NoobforAl/omnitun/server/tlsfiles"
	"github.com/NoobforAl/omnitun/server/tui"
)

func newRunCmd(global *options) *cobra.Command {
	var pprofAddr, logLevel string
	cmd := &cobra.Command{
		Use:   "run",
		Short: "Start the server (reloads when users change); serves the web API if enabled",
		Long: `Start the server. It reloads when users change and serves the web API if enabled.

What it logs goes to server.log in the data directory and to stderr (the
systemd journal), one JSON record per line; ` + "`omnitun-server logs`" + ` shows them.
Failures nothing handles are also alerts: ` + "`omnitun-server alerts`" + `.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) (err error) {
			mgr := global.manager()
			// Checked before the server starts, so a typo does not leave it half up.
			var override *logs.Level
			if logLevel != "" && logLevel != "default" {
				level, ok := logs.ParseLevel(logLevel)
				if !ok || level == logs.LevelFatal {
					return fmt.Errorf("%w: unknown log level %q (trace, debug, info, warn or error)", manager.ErrInvalid, logLevel)
				}
				override = &level
			}
			var pprofLn net.Listener
			if pprofAddr != "" {
				if pprofLn, err = pprofsrv.Listen(pprofAddr); err != nil {
					return err
				}
				defer pprofLn.Close()
			}
			// From here on everything this command reports is a record in
			// server.log and on stderr.
			srv := runtime.New(mgr.Store, nil)
			serverLog := srv.Log()
			serverLog.SetMirror(os.Stderr)
			serverLog.SetAlerts(logs.OpenAlerts(mgr.Store.Dir)) // until the config is read
			if override != nil {
				srv.SetLogLevel(*override)
			}
			defer func() {
				if value := recover(); value != nil {
					serverLog.LogPanic(value, "server", "run")
					err = fmt.Errorf("panic: %v", value)
				}
			}()
			if err := srv.Start(); err != nil {
				serverLog.Log(logs.LevelError, logs.Record{Msg: "the server did not start", Op: "start", Code: "START_FAILED", Err: logs.Scrub(err.Error()), Notify: true})
				return err
			}
			ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
			defer stop()
			var wg sync.WaitGroup
			wg.Go(func() { srv.Watch(ctx) })
			if pprofLn != nil {
				wg.Go(func() {
					defer recoverInto(serverLog, "pprof")
					if err := pprofsrv.ServeListener(ctx, pprofLn, recordf(serverLog, "pprof")); err != nil {
						serverLog.Log(logs.LevelError, logs.Record{Msg: "the profile server stopped", Target: "pprof", Op: "serve", Code: "STOPPED", Err: logs.Scrub(err.Error())})
					}
				})
			}

			if a, err := mgr.API(); err == nil && a.Enabled {
				handler := api.New(api.Options{Manager: mgr, Token: liveToken(mgr), Reload: srv.Reload, Log: serverLog})
				wg.Go(func() {
					defer recoverInto(serverLog, "api")
					if err := api.Serve(ctx, a.Listen, a.Port, handler, apiTLS(mgr, a), recordf(serverLog, "api")); err != nil {
						serverLog.Log(logs.LevelError, logs.Record{Msg: "the web API stopped", Target: "api", Op: "serve", Code: "STOPPED", Err: logs.Scrub(err.Error()), Notify: true})
					}
				})
			}
			serverLog.Log(logs.LevelInfo, logs.Record{Msg: "running; Ctrl+C to stop", Op: "start"})
			<-ctx.Done()
			wg.Wait()
			return srv.Close()
		},
	}
	cmd.Flags().StringVar(&pprofAddr, "pprof", "", "serve Go runtime profiles on this loopback address, e.g. 127.0.0.1:6060 (off by default)")
	cmd.Flags().StringVar(&logLevel, "log-level", "", "for this run, the "+levelHelp)
	return cmd
}

// recordf turns the printf-style messages of the web API and the profile
// server into records: "warning: …" is a warning, net/http's own messages
// ("http: TLS handshake error from …") are debug records without addresses.
func recordf(serverLog *logs.Log, target string) func(string, ...any) {
	return func(format string, args ...any) {
		message, level := fmt.Sprintf(format, args...), logs.LevelInfo
		switch {
		case strings.HasPrefix(message, "warning: "):
			message, level = strings.TrimPrefix(message, "warning: "), logs.LevelWarn
		case strings.HasPrefix(message, "http: "):
			message, level = logs.Scrub(message), logs.LevelDebug
		}
		serverLog.Log(level, logs.Record{Target: target, Msg: message})
	}
}

// recoverInto logs a panic of a goroutine of `run` (a fatal record and an
// alert) and ends that goroutine; use it deferred.
func recoverInto(serverLog *logs.Log, target string) {
	if value := recover(); value != nil {
		serverLog.LogPanic(value, target, "serve")
	}
}

// apiTLS is the HTTPS configuration of the web API (nil for plain HTTP): the
// server's certificate, the ACME one when there is one.
func apiTLS(mgr *manager.Manager, api store.API) *tls.Config {
	if !api.TLS {
		return nil
	}
	st, err := mgr.Store.Load()
	if err != nil {
		return nil
	}
	domain := ""
	if st.Server.ACMEActive() {
		domain = st.Server.ACME.Domain
	}
	return tlsfiles.New(serverconf.ACMEDir(mgr.Store), domain, mgr.Store.Path(st.Server.CertFile), mgr.Store.Path(st.Server.KeyFile)).TLSConfig()
}

// tokenTTL bounds how long a rotated or disabled token can still be accepted
// by a running server, whatever the file system's timestamp resolution.
var tokenTTL = 2 * time.Second

// liveToken returns the API's current token, re-read from the state file at
// least every tokenTTL (and sooner when its size or modification time change),
// so `api token --new` and `api disable` take effect on a running server
// without a restart.
func liveToken(mgr *manager.Manager) func() string {
	var (
		mu      sync.Mutex
		at      time.Time
		modTime time.Time
		size    int64
		token   string
	)
	return func() string {
		mu.Lock()
		defer mu.Unlock()
		mt, sz := mgr.Store.ModTime(), mgr.Store.Size()
		if time.Since(at) < tokenTTL && mt.Equal(modTime) && sz == size {
			return token
		}
		at, modTime, size, token = time.Now(), mt, sz, ""
		if a, err := mgr.API(); err == nil && a.Enabled {
			token = a.Token
		}
		return token
	}
}

func newTUICmd(global *options) *cobra.Command {
	return &cobra.Command{
		Use:   "tui",
		Short: "Interactive user and server manager",
		Args:  cobra.NoArgs,
		RunE:  func(cmd *cobra.Command, args []string) error { return tui.Run(global.manager().Store) },
	}
}

func newAPICmd(global *options) *cobra.Command {
	cmd := &cobra.Command{Use: "api", Short: "Configure the web API (served by `run`)"}

	show := func(api store.API) func() {
		return func() {
			state := "disabled"
			if api.Enabled {
				state = "enabled"
			}
			scheme := "http"
			if api.TLS {
				scheme = "https"
			}
			fmt.Printf("web API: %s, listening on %s:%d (%s)\n", state, api.Listen, api.Port, scheme)
			fmt.Printf("token:   %s\n", api.Token)
			fmt.Printf("docs:    %s://%s:%d/docs\n", scheme, api.Listen, api.Port)
		}
	}
	apply := func(p func() (store.API, error)) error {
		a, err := p()
		if err != nil {
			return err
		}
		return global.print(a, show(a))
	}

	status := &cobra.Command{
		Use: "status", Short: "Show the web API settings and token", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error { return apply(global.manager().API) },
	}
	enable := func(use string, on bool) *cobra.Command {
		return &cobra.Command{
			Use: use, Short: "Turn the web API " + map[bool]string{true: "on (starts with the next `run`)", false: "off (a running server stops accepting its token at once)"}[on], Args: cobra.NoArgs,
			RunE: func(cmd *cobra.Command, args []string) error {
				return apply(func() (store.API, error) { return global.manager().SetAPI(apiPatchEnabled(on)) })
			},
		}
	}
	token := &cobra.Command{
		Use: "token", Short: "Print the API token; --new issues a fresh one (the old one stops working at once, even on a running server)", Args: cobra.NoArgs,
	}
	newToken := token.Flags().Bool("new", false, "issue a new token (the old one stops working)")
	token.RunE = func(cmd *cobra.Command, args []string) error {
		return apply(func() (store.API, error) {
			if *newToken {
				return global.manager().SetAPI(apiPatchToken())
			}
			return global.manager().API()
		})
	}
	listen := &cobra.Command{
		Use: "listen <host> [port]", Short: "Set the listen address, e.g. 127.0.0.1 or 0.0.0.0", Args: cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			host := args[0]
			var port *int
			if len(args) == 2 {
				n, err := strconv.Atoi(args[1])
				if err != nil {
					return fmt.Errorf("invalid port %q", args[1])
				}
				port = &n
			}
			return apply(func() (store.API, error) { return global.manager().SetAPI(apiPatchListen(host, port)) })
		},
	}
	tlsCmd := &cobra.Command{
		Use: "tls <on|off>", Short: "Serve the web API over HTTPS with the server's certificate (applies on the next `run`)",
		Args: cobra.ExactArgs(1), ValidArgs: []string{"on", "off"},
		RunE: func(cmd *cobra.Command, args []string) error {
			if args[0] != "on" && args[0] != "off" {
				return fmt.Errorf("%w: use on or off", manager.ErrInvalid)
			}
			on := args[0] == "on"
			return apply(func() (store.API, error) { return global.manager().SetAPI(manager.APIPatch{TLS: &on}) })
		},
	}
	cmd.AddCommand(status, enable("enable", true), enable("disable", false), token, listen, tlsCmd)
	return cmd
}

func newServiceCmd(global *options) *cobra.Command {
	var user string
	cmd := &cobra.Command{
		Use:   "service",
		Short: "Print the systemd unit for this server (`install` writes the same one)",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			exe, err := os.Executable()
			if err != nil {
				return err
			}
			dir, _ := filepath.Abs(global.dataDir)
			if user == "root" {
				user = ""
			}
			fmt.Printf("# Save as %s, then:\n#   systemctl daemon-reload && systemctl enable --now %s\n", install.UnitPath, install.UnitName)
			fmt.Print(install.Unit(filepath.ToSlash(exe), filepath.ToSlash(dir), user, hostServers(global)))
			return nil
		},
	}
	cmd.Flags().StringVar(&user, "user", "root", "user the service runs as")
	return cmd
}
