// Package runtime runs the VPN server: a sing-box instance built from the
// state file plus the subscription endpoint. It reloads when the state file
// changes, so `omnitun-server user ...` and the TUI apply without a restart.
package runtime

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/common/trafficcontrol"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	sjson "github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/service"

	"github.com/NoobforAl/omnitun/core/protocols"
	"github.com/NoobforAl/omnitun/server/hostproto"
	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/stats"
	"github.com/NoobforAl/omnitun/server/store"
	"github.com/NoobforAl/omnitun/server/tlsfiles"
)

// Server is a running VPN server.
type Server struct {
	store *store.Store

	levelMu       sync.Mutex
	levelOverride *logs.Level // run --log-level: wins over the config
	started       time.Time
	certChecked   time.Time // last checkCertificate (guarded by mu)

	mu       sync.Mutex
	instance *box.Box
	cancel   context.CancelFunc
	sub      *http.Server
	loaded   time.Time // state file mod time of the running config
	fp       string    // listenerFingerprint of the state the running listeners were built from

	log     *logs.Log      // server.log
	tracker *stats.Tracker // per-user traffic, shared by every sing-box run
	accMu   sync.Mutex     // guards the collector's tick against the final flush
	coll    *collector     // the running instance's collector (guarded by accMu)
	accStop context.CancelFunc

	hosts   map[string]hostproto.Server // running host-level servers (AmneziaWG, DNSCrypt)
	dnstt   *dnsttSidecar               // the DNS tunnel's front end, when it runs
	undoNAT func()
	meters  hostMeters       // per-user traffic of the host-level servers
	runner  hostproto.Runner // runs nft/iptables; tests replace it

	wgMu    sync.RWMutex
	wgUsers map[netip.Addr]string // WireGuard tunnel address -> user name
	ovpn    ovpnUsers             // OpenVPN tunnel address -> user name
}

// setWireGuardUsers remembers which user owns which tunnel address.
func (s *Server) setWireGuardUsers(st *store.State) {
	byAddr := map[netip.Addr]string{}
	for _, user := range st.Users {
		if p, err := netip.ParsePrefix(user.WGAddress); err == nil {
			byAddr[p.Addr()] = user.Name
			if a6, err := protocols.WGAddress6(user.WGAddress); err == nil {
				if p6, err := netip.ParsePrefix(a6); err == nil {
					byAddr[p6.Addr()] = user.Name // the IPv6 address of a server with IPv6 on
				}
			}
		}
	}
	s.wgMu.Lock()
	s.wgUsers = byAddr
	s.wgMu.Unlock()
}

// userByTunnelIP names the user behind a WireGuard or OpenVPN tunnel address.
func (s *Server) userByTunnelIP(addr netip.Addr) string {
	addr = addr.Unmap()
	s.wgMu.RLock()
	u := s.wgUsers[addr]
	s.wgMu.RUnlock()
	if u != "" {
		return u
	}
	return s.ovpn.user(addr)
}

// New prepares a server for the store. Everything it logs goes to server.log,
// where the CLI, the TUI and the API read it; echo (may be nil) also gets every
// record's line (tests pass t.Logf; `run` mirrors the log to stderr instead).
func New(stateStore *store.Store, echo func(string, ...any)) *Server {
	file := logs.Open(stateStore.Dir)
	if echo != nil {
		file.SetMirror(lineFunc(func(line string) { echo("%s", line) }))
	}
	return &Server{store: stateStore, log: file, runner: hostproto.ExecRunner{}}
}

// lineFunc is an io.Writer that hands each written line to a function.
type lineFunc func(line string)

func (f lineFunc) Write(p []byte) (int, error) {
	f(strings.TrimRight(string(p), "\n"))
	return len(p), nil
}

// Log is the server's log: `run` mirrors it to stderr and writes its own records there.
func (s *Server) Log() *logs.Log { return s.log }

// SetLogLevel makes level win over the configured one (run --log-level).
func (s *Server) SetLogLevel(level logs.Level) {
	s.levelMu.Lock()
	s.levelOverride = &level
	s.levelMu.Unlock()
	s.log.SetLevel(level)
}

// applyLogging sets the log level and the alerts from the state (the
// override wins over the configured level).
func (s *Server) applyLogging(st *store.State) {
	level := logs.DefaultLevel()
	if configured, ok := logs.ParseLevel(st.Server.Logging.LevelName()); ok {
		level = configured
	}
	s.levelMu.Lock()
	if s.levelOverride != nil {
		level = *s.levelOverride
	}
	s.levelMu.Unlock()
	s.log.SetLevel(level)
	if st.Server.Logging.AlertsEnabled() {
		s.log.SetAlerts(logs.OpenAlerts(s.store.Dir))
	} else {
		s.log.SetAlerts(nil)
	}
}

// logf writes a server record; the message is only formatted when the log keeps level.
func (s *Server) logf(level logs.Level, format string, args ...any) {
	if s.log.Enabled(level) {
		s.log.Log(level, logs.Record{Msg: fmt.Sprintf(format, args...)})
	}
}

// failed writes an error record. With notify, nothing else handles the
// failure: it is also an alert. The error's text is scrubbed of addresses.
func (s *Server) failed(notify bool, rec logs.Record, err error) {
	if !s.log.Enabled(logs.LevelError) {
		return
	}
	if err != nil {
		rec.Err = logs.Scrub(err.Error())
	}
	rec.Notify = notify
	s.log.Log(logs.LevelError, rec)
}

// recovered logs a panic of a long-running goroutine as a fatal record (and
// an alert) and ends that work instead of the process. Use it deferred:
// `defer s.recovered("runtime", "watch")`.
func (s *Server) recovered(target, op string) {
	if value := recover(); value != nil {
		s.log.LogPanic(value, target, op)
	}
}

// recoverHandler answers 500 to a request whose handler panicked and logs
// the panic, instead of net/http's text on stderr.
func (s *Server) recoverHandler(target string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if value := recover(); value != nil {
				if value == http.ErrAbortHandler { //nolint:errorlint // recover() value, not a returned error; net/http panics with this exact sentinel
					panic(value)
				}
				s.log.LogPanic(value, target, "request")
				http.Error(w, "internal error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// Start loads the state and starts sing-box and the subscription endpoint.
func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	st, err := s.store.Load()
	if err != nil {
		return err
	}
	s.applyLogging(st)
	s.started = time.Now()
	s.tracker = stats.NewTracker(s.store.Dir)
	s.setWireGuardUsers(st)
	s.watchOpenVPN()
	accCtx, accCancel := context.WithCancel(context.Background())
	s.accStop = accCancel
	go s.accountingLoop(accCtx)
	if renewed, err := store.RenewSelfSignedCert(s.store, st); err != nil {
		return fmt.Errorf("renew certificate: %w", err)
	} else if renewed {
		s.logf(logs.LevelInfo, "issued a new self-signed certificate (valid %d days)", int(store.SelfSignedValidity.Hours()/24))
	}
	if err := s.startBoxLocked(st); err != nil {
		return err
	}
	s.startHostLocked(st)
	s.startDNSTTLocked(st)
	if sub := st.Server.Subscription; sub.Enabled {
		ln, err := net.Listen("tcp", net.JoinHostPort(sub.Listen, strconv.Itoa(sub.Port)))
		if err != nil {
			s.stopBoxLocked()
			return fmt.Errorf("subscription endpoint: %w", err)
		}
		sub := &http.Server{
			Handler:           s.recoverHandler("subscription", serverconf.SubscriptionHandler(s.store)),
			ReadHeaderTimeout: 10 * time.Second,
			ErrorLog:          s.httpErrorLog("subscription"),
		}
		s.sub = sub
		serve, scheme := func() error { return sub.Serve(ln) }, "http"
		if st.Server.ACMEActive() {
			src := tlsfiles.New(serverconf.ACMEDir(s.store), st.Server.ACME.Domain, s.store.Path(st.Server.CertFile), s.store.Path(st.Server.KeyFile))
			sub.TLSConfig = src.TLSConfig()
			serve, scheme = func() error { return sub.ServeTLS(ln, "", "") }, "https"
		}
		go func() {
			defer s.recovered("subscription", "serve")
			if err := serve(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				s.failed(true, logs.Record{Msg: "the subscription endpoint stopped", Target: "subscription", Op: "serve", Code: "STOPPED"}, err)
			}
		}()
		s.logf(logs.LevelInfo, "subscriptions on %s://%s", scheme, ln.Addr())
	}
	return nil
}

func (s *Server) startBoxLocked(st *store.State) error {
	s.loaded = s.store.ModTime()
	s.fp = listenerFingerprint(st)
	cfg := serverconf.Build(st, s.store, time.Now())
	inbounds, _ := cfg["inbounds"].([]any)
	endpoints, _ := cfg["endpoints"].([]any)
	if len(inbounds)+len(endpoints) == 0 {
		s.logf(logs.LevelInfo, "no active users or protocols; waiting for changes")
		return nil
	}
	// sing-box's own console output is off: what it logs reaches server.log
	// as records through the platform writer (sbLog).
	cfg["log"] = map[string]any{"level": "fatal", "output": os.DevNull}
	raw, err := json.Marshal(cfg)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithCancel(include.Context(context.Background()))
	opts, err := sjson.UnmarshalExtendedContext[option.Options](ctx, raw)
	if err == nil {
		var instance *box.Box
		// The platform writer makes sing-box create its traffic manager,
		// which the accounting reads.
		instance, err = box.New(box.Options{Context: ctx, Options: opts, PlatformLogWriter: sbLog{s.log}})
		if err == nil {
			if err = instance.Start(); err == nil {
				s.instance, s.cancel = instance, cancel
				if tm := service.PtrFromContext[trafficcontrol.Manager](ctx); tm != nil {
					s.accMu.Lock()
					s.coll = newCollector(tm, s.tracker, s.userByTunnelIP, s.log)
					s.accMu.Unlock()
				}
				s.logf(logs.LevelInfo, "serving %d protocol(s) for %d user(s)", len(inbounds)+len(endpoints), len(st.ActiveUsers(time.Now())))
				return nil
			}
			instance.Close()
		}
	}
	cancel()
	return fmt.Errorf("start sing-box: %w", err)
}

func (s *Server) stopBoxLocked() {
	// Count what the connections moved since the last tick before they close.
	s.accMu.Lock()
	coll := s.coll
	if coll != nil {
		_, _ = coll.tick() // the last numbers of this run; the next tick publishes without it
		s.coll = nil
	}
	s.accMu.Unlock()
	if s.instance != nil {
		s.instance.Close()
		s.cancel()
		s.instance, s.cancel = nil, nil
	}
	// Closing ended the connections; count their last bytes.
	if coll != nil {
		coll.finish()
	}
}

// listenerFingerprint hashes the state the listeners (sing-box and the host
// protocols) are built from. It leaves out only what they provably never read:
// a user's note and quota figure and their usage-reset request (the accounting
// loop reads those from the file itself) and the API settings (the API is
// served on its own). Anything else, including a field added later, changes it,
// so a change that matters always restarts the listeners.
func listenerFingerprint(st *store.State) string {
	trimmed := *st
	trimmed.Server.API = store.API{}
	trimmed.Server.Logging = nil // applied without a restart
	// The subscription endpoint reads these from the file on every request; no listener does.
	trimmed.Server.Subscription.ProtocolOrder, trimmed.Server.Subscription.SigningKey = nil, ""
	trimmed.Users = make([]*store.User, len(st.Users))
	for i, u := range st.Users {
		v := *u
		v.Note, v.QuotaGB, v.UsageResetAt = "", 0, nil
		trimmed.Users[i] = &v
	}
	raw, err := json.Marshal(&trimmed)
	if err != nil {
		return "" // never equal: the listeners are restarted
	}
	sum := sha256.Sum256(raw)
	return hex.EncodeToString(sum[:])
}

// Reload restarts sing-box with the current state (brief interruption for
// connected clients).
func (s *Server) Reload() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	st, err := s.store.Load()
	if err != nil {
		return err
	}
	s.stopBoxLocked()
	s.stopHostLocked()
	err = s.startBoxLocked(st)
	s.startHostLocked(st)
	s.startDNSTTLocked(st)
	return err
}

// Watch reloads when the state file changes and once a minute (to apply
// expirations), until ctx is done. A panic in it is logged (and is an alert)
// and the watch goes on after a pause.
func (s *Server) Watch(ctx context.Context) {
	for !s.watch(ctx) {
		select {
		case <-ctx.Done():
			return
		case <-time.After(5 * time.Second):
		}
	}
}

// watch is Watch's loop; it reports false when it ended in a panic.
func (s *Server) watch(ctx context.Context) (done bool) {
	defer s.recovered("runtime", "watch")
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	lastMinute := time.Now()
	for {
		select {
		case <-ctx.Done():
			return true
		case <-ticker.C:
		}
		s.mu.Lock()
		changed := !s.store.ModTime().Equal(s.loaded)
		s.mu.Unlock()
		if changed || time.Since(lastMinute) >= time.Minute {
			lastMinute = time.Now()
			if err := s.reloadIfNeeded(changed); err != nil {
				// The next minute tries again, but until then (or for good) the
				// protocols are down: the admin should know.
				s.failed(true, logs.Record{Msg: "reload failed; the VPN protocols may be down", Target: "sing-box", Op: "reload", Code: "RELOAD_FAILED"}, err)
			}
			s.checkCertificate()
		}
	}
}

// reloadIfNeeded reloads on file changes, or when the set of active users
// changed because someone expired.
func (s *Server) reloadIfNeeded(changed bool) error {
	modified := s.store.ModTime() // before reading, so a change made meanwhile is seen next time
	st, err := s.store.Load()
	if err != nil {
		return err
	}
	s.applyLogging(st)
	if changed {
		s.mu.Lock()
		same := s.fp != "" && s.fp == listenerFingerprint(st)
		if same {
			s.loaded = modified
		}
		s.mu.Unlock()
		if !same {
			s.logf(logs.LevelInfo, "state changed, reloading")
			return s.Reload()
		}
		// A note, a quota figure or the API settings: nothing a listener was built from, so nobody is disconnected.
		s.logf(logs.LevelDebug, "state changed, nothing the listeners use: no restart")
	}
	s.mu.Lock()
	running := s.instance != nil
	s.mu.Unlock()
	if !running && len(st.ActiveUsers(time.Now())) > 0 {
		return s.Reload()
	}
	for _, u := range st.Users {
		if u.Enabled && u.ExpiresAt != nil && time.Since(*u.ExpiresAt) >= 0 && time.Since(*u.ExpiresAt) < time.Minute+5*time.Second {
			s.log.Log(logs.LevelInfo, logs.Record{Msg: "user expired, reloading", User: u.Name, Op: "reload"})
			return s.Reload()
		}
	}
	return nil
}

// Close stops everything.
func (s *Server) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stopBoxLocked()
	s.stopHostLocked()
	s.stopWatchingOpenVPN()
	defer s.log.Close()
	if s.accStop != nil {
		s.accStop()
	}
	if s.tracker != nil {
		if err := s.tracker.Stop(); err != nil {
			s.failed(false, logs.Record{Msg: "saving the traffic stats failed", Op: "stats", Code: "STATS_SAVE_FAILED"}, err)
		}
	}
	var err error
	if s.sub != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		err = s.sub.Shutdown(ctx)
		if errors.Is(err, http.ErrServerClosed) {
			err = nil
		}
	}
	return err
}
