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
	"strconv"
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
	logf  func(format string, args ...any)

	mu       sync.Mutex
	instance *box.Box
	cancel   context.CancelFunc
	sub      *http.Server
	loaded   time.Time // state file mod time of the running config
	fp       string    // listenerFingerprint of the state the running listeners were built from

	file    *logs.Log      // server.log
	tracker *stats.Tracker // per-user traffic, shared by every sing-box run
	accMu   sync.Mutex     // guards the collector's tick against the final flush
	coll    *collector     // the running instance's collector (guarded by accMu)
	accStop context.CancelFunc

	hosts   map[string]hostproto.Server // running SSTP / IKEv2 servers
	undoNAT func()
	meters  hostMeters       // per-user traffic of the host-level servers
	runner  hostproto.Runner // runs nft/iptables; tests replace it

	wgMu    sync.RWMutex
	wgUsers map[netip.Addr]string // WireGuard tunnel address -> user name
	ovpn    ovpnUsers             // OpenVPN tunnel address -> user name
}

// setWireGuardUsers remembers which user owns which tunnel address.
func (s *Server) setWireGuardUsers(st *store.State) {
	m := map[netip.Addr]string{}
	for _, u := range st.Users {
		if p, err := netip.ParsePrefix(u.WGAddress); err == nil {
			m[p.Addr()] = u.Name
			if a6, err := protocols.WGAddress6(u.WGAddress); err == nil {
				if p6, err := netip.ParsePrefix(a6); err == nil {
					m[p6.Addr()] = u.Name // the IPv6 address of a server with IPv6 on
				}
			}
		}
	}
	s.wgMu.Lock()
	s.wgUsers = m
	s.wgMu.Unlock()
}

// userByTunnelIP names the user behind a WireGuard or OpenVPN tunnel address.
func (s *Server) userByTunnelIP(a netip.Addr) string {
	a = a.Unmap()
	s.wgMu.RLock()
	u := s.wgUsers[a]
	s.wgMu.RUnlock()
	if u != "" {
		return u
	}
	return s.ovpn.user(a)
}

// New prepares a server for the store.
func New(s *store.Store, logf func(string, ...any)) *Server {
	if logf == nil {
		logf = func(string, ...any) {}
	}
	// Everything the server says also goes to server.log, where the CLI, the
	// TUI and the API can read it.
	file := logs.Open(s.Dir)
	srv := &Server{store: s, file: file, runner: hostproto.ExecRunner{}}
	srv.logf = func(format string, args ...any) {
		logf(format, args...)
		file.Write("info", fmt.Sprintf(format, args...))
	}
	return srv
}

// Start loads the state and starts sing-box and the subscription endpoint.
func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	st, err := s.store.Load()
	if err != nil {
		return err
	}
	s.tracker = stats.NewTracker(s.store.Dir)
	s.setWireGuardUsers(st)
	s.watchOpenVPN()
	accCtx, accCancel := context.WithCancel(context.Background())
	s.accStop = accCancel
	go s.accountingLoop(accCtx)
	if renewed, err := store.RenewSelfSignedCert(s.store, st); err != nil {
		return fmt.Errorf("renew certificate: %w", err)
	} else if renewed {
		s.logf("issued a new self-signed certificate (valid %d days)", int(store.SelfSignedValidity.Hours()/24))
	}
	if err := s.startBoxLocked(st); err != nil {
		return err
	}
	s.startHostLocked(st)
	if sub := st.Server.Subscription; sub.Enabled {
		ln, err := net.Listen("tcp", net.JoinHostPort(sub.Listen, strconv.Itoa(sub.Port)))
		if err != nil {
			s.stopBoxLocked()
			return fmt.Errorf("subscription endpoint: %w", err)
		}
		s.sub = &http.Server{Handler: serverconf.SubscriptionHandler(s.store), ReadHeaderTimeout: 10 * time.Second}
		if st.Server.ACMEActive() {
			src := tlsfiles.New(serverconf.ACMEDir(s.store), st.Server.ACME.Domain, s.store.Path(st.Server.CertFile), s.store.Path(st.Server.KeyFile))
			s.sub.TLSConfig = src.TLSConfig()
			go s.sub.ServeTLS(ln, "", "")
			s.logf("subscriptions on https://%s", ln.Addr())
		} else {
			go s.sub.Serve(ln)
			s.logf("subscriptions on %s", ln.Addr())
		}
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
		s.logf("no active users or protocols; waiting for changes")
		return nil
	}
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
		instance, err = box.New(box.Options{Context: ctx, Options: opts, PlatformLogWriter: sbLog{s.file}})
		if err == nil {
			if err = instance.Start(); err == nil {
				s.instance, s.cancel = instance, cancel
				if tm := service.PtrFromContext[trafficcontrol.Manager](ctx); tm != nil {
					s.accMu.Lock()
					s.coll = newCollector(tm, s.tracker, s.userByTunnelIP)
					s.accMu.Unlock()
				}
				s.logf("serving %d protocol(s) for %d user(s)", len(inbounds)+len(endpoints), len(st.ActiveUsers(time.Now())))
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
	c := *st
	c.Server.API = store.API{}
	c.Users = make([]*store.User, len(st.Users))
	for i, u := range st.Users {
		v := *u
		v.Note, v.QuotaGB, v.UsageResetAt = "", 0, nil
		c.Users[i] = &v
	}
	raw, err := json.Marshal(&c)
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
	return err
}

// Watch reloads when the state file changes and once a minute (to apply
// expirations), until ctx is done.
func (s *Server) Watch(ctx context.Context) {
	t := time.NewTicker(2 * time.Second)
	defer t.Stop()
	lastMinute := time.Now()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
		s.mu.Lock()
		changed := !s.store.ModTime().Equal(s.loaded)
		s.mu.Unlock()
		if changed || time.Since(lastMinute) >= time.Minute {
			lastMinute = time.Now()
			if err := s.reloadIfNeeded(changed); err != nil {
				s.logf("reload failed: %v", err)
			}
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
	if changed {
		s.mu.Lock()
		same := s.fp != "" && s.fp == listenerFingerprint(st)
		if same {
			s.loaded = modified
		}
		s.mu.Unlock()
		if !same {
			s.logf("state changed, reloading")
			return s.Reload()
		}
		// A note, a quota figure or the API settings: nothing a listener was built from, so nobody is disconnected.
		s.logf("state changed, nothing the listeners use: no restart")
	}
	s.mu.Lock()
	running := s.instance != nil
	s.mu.Unlock()
	if !running && len(st.ActiveUsers(time.Now())) > 0 {
		return s.Reload()
	}
	for _, u := range st.Users {
		if u.Enabled && u.ExpiresAt != nil && time.Since(*u.ExpiresAt) >= 0 && time.Since(*u.ExpiresAt) < time.Minute+5*time.Second {
			s.logf("user %s expired, reloading", u.Name)
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
	defer s.file.Close()
	if s.accStop != nil {
		s.accStop()
	}
	if s.tracker != nil {
		if err := s.tracker.Stop(); err != nil {
			s.logf("save stats: %v", err)
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
