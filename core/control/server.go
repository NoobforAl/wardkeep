package control

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/subtle"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/common/certificate"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/logger"

	"github.com/NoobforAl/omnitun/core/dnstt"
	"github.com/NoobforAl/omnitun/core/engine"
	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/killswitch"
	"github.com/NoobforAl/omnitun/core/links"
	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/netcheck"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
	"github.com/NoobforAl/omnitun/core/subscription"
)

const (
	maxLine = 8 << 20
	// readTimeout closes clients that stop sending (the UI pings every few seconds).
	readTimeout = 15 * time.Second
	sendBuffer  = 256
)

// ServerConfig configures the daemon.
type ServerConfig struct {
	// DataDir is passed to the engine.
	DataDir string
	// Grace is how long the tunnel survives with no UI connected. Zero means 5s;
	// negative disables the lease (mobile: the OS reports app closure instead).
	Grace time.Duration
	// Token authenticates clients. Empty generates a random one.
	Token string
	// OnLog receives every log record (the engine's and the server's own), after clients are sent it; the
	// records are already gated by the level and scrubbed.
	OnLog func(logrec.Record)
	// Logf receives the server's own messages as text (kill switch, lease). Deprecated: use OnLog.
	Logf func(format string, args ...any)
	// NetCheck reports whether the underlying network is up. Nil uses netcheck.Online.
	NetCheck func(ctx context.Context) error
	// CertificateStore is passed to the engine (see engine.Config).
	CertificateStore string
	// SkipHandshake is passed to the engine (tests with unreachable servers).
	SkipHandshake bool
	// Platform is passed to the engine (mobile only).
	Platform adapter.PlatformInterface
	// Tun is passed to the engine (mobile only; AmneziaWG).
	Tun engine.TunProvider
	// OnState is called on every engine state change, after clients are notified.
	OnState func(engine.State)
	// KillSwitch arms the Windows kill switch for "start" requests that ask
	// for it (core/killswitch). Nil: such requests are refused.
	KillSwitch *killswitch.Manager
	// KillSwitchResolver looks up the VPN servers' names for the kill switch
	// (tests); nil uses the system resolver.
	KillSwitchResolver killswitch.Resolver
}

// Server owns the engine and serves UI clients.
type Server struct {
	cfg    ServerConfig
	engine *engine.Engine
	ks     ksState

	mu         sync.Mutex
	clients    map[*client]struct{}
	graceTimer *time.Timer
	ln         net.Listener
	pool       *x509.CertPool
	closed     bool
}

type client struct {
	conn net.Conn
	send chan any
	done chan struct{}
	once sync.Once
}

func (c *client) close() {
	c.once.Do(func() {
		close(c.done)
		c.conn.Close()
	})
}

// NewServer creates a server and its engine.
func NewServer(cfg ServerConfig) (*Server, error) {
	if cfg.Grace == 0 {
		cfg.Grace = 5 * time.Second
	}
	if cfg.Token == "" {
		b := make([]byte, 32)
		if _, err := rand.Read(b); err != nil {
			return nil, err
		}
		cfg.Token = hex.EncodeToString(b)
	}
	if cfg.NetCheck == nil {
		cfg.NetCheck = netcheck.Online
	}
	srv := &Server{cfg: cfg, clients: map[*client]struct{}{}}
	srv.engine = engine.New(engine.Config{
		DataDir:          cfg.DataDir,
		Platform:         cfg.Platform,
		Tun:              cfg.Tun,
		CertificateStore: cfg.CertificateStore,
		SkipHandshake:    cfg.SkipHandshake,
		OnState: func(st engine.State) {
			srv.ksOnState(st)
			srv.broadcast(Event{Event: "state", Data: st})
			if cfg.OnState != nil {
				cfg.OnState(st)
			}
		},
		OnLog: srv.publishLog,
	})
	return srv, nil
}

// Token returns the client authentication token.
func (s *Server) Token() string { return s.cfg.Token }

// Engine exposes the engine (for tests and the CLI).
func (s *Server) Engine() *engine.Engine { return s.engine }

// Listen binds addr (use 127.0.0.1:0 for a random port).
func (s *Server) Listen(addr string) (net.Addr, error) {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	s.ln = ln
	s.mu.Unlock()
	return ln.Addr(), nil
}

// WriteControlFile stores the address and token for clients, readable only by the current user.
func (s *Server) WriteControlFile(path string) error {
	s.mu.Lock()
	ln := s.ln
	s.mu.Unlock()
	if ln == nil {
		return errors.New("not listening")
	}
	data, err := json.Marshal(ControlFile{Addr: ln.Addr().String(), Token: s.cfg.Token, PID: os.Getpid()})
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// Serve accepts clients until Close.
func (s *Server) Serve() error {
	s.mu.Lock()
	ln := s.ln
	s.mu.Unlock()
	if ln == nil {
		return errors.New("not listening")
	}
	for {
		conn, err := ln.Accept()
		if err != nil {
			s.mu.Lock()
			closed := s.closed
			s.mu.Unlock()
			if closed {
				return nil
			}
			return err
		}
		go func() {
			defer s.recoverGoroutine("control")
			s.handle(conn)
		}()
	}
}

// Close stops the tunnel, disconnects clients and stops listening.
func (s *Server) Close() error {
	s.mu.Lock()
	s.closed = true
	if s.ln != nil {
		s.ln.Close()
	}
	if s.graceTimer != nil {
		s.graceTimer.Stop()
	}
	clients := s.clients
	s.clients = map[*client]struct{}{}
	s.mu.Unlock()
	for c := range clients {
		c.close()
	}
	err := s.engine.Stop()
	s.ksStop()
	return err
}

// broadcast queues an event for every client without blocking; slow clients drop events.
func (s *Server) broadcast(ev Event) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for c := range s.clients {
		select {
		case c.send <- ev:
		default:
		}
	}
}

func (s *Server) addClient(c *client) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.clients[c] = struct{}{}
	if s.graceTimer != nil {
		s.graceTimer.Stop()
		s.graceTimer = nil
	}
}

// removeClient starts the grace timer when the last client leaves: a tunnel
// must never outlive the UI that controls it.
func (s *Server) removeClient(cl *client) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.clients[cl]; !ok {
		return
	}
	delete(s.clients, cl)
	if len(s.clients) > 0 || s.closed || s.cfg.Grace < 0 {
		return
	}
	s.graceTimer = time.AfterFunc(s.cfg.Grace, func() {
		s.mu.Lock()
		idle := len(s.clients) == 0
		s.mu.Unlock()
		if idle && s.engine.State().Status != engine.StatusStopped {
			s.logf(logrec.LevelInfo, "no UI connected for %s, stopping tunnel", s.cfg.Grace)
			s.engine.Stop()
		}
		if idle {
			s.ksStop() // the UI is gone: a kill switch kept after an internal stop ends with it
		}
	})
}

func (s *Server) handle(conn net.Conn) {
	cl := &client{conn: conn, send: make(chan any, sendBuffer), done: make(chan struct{})}
	defer cl.close()

	go func() {
		defer s.recoverGoroutine("control")
		defer cl.close()
		enc := json.NewEncoder(conn)
		for {
			select {
			case <-cl.done:
				return
			case msg := <-cl.send:
				if m, ok := msg.(flushMarker); ok {
					close(m)
					continue
				}
				conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if err := enc.Encode(msg); err != nil {
					cl.close()
					return
				}
			}
		}
	}()

	sc := bufio.NewScanner(conn)
	sc.Buffer(make([]byte, 4<<10), maxLine)
	authed := false
	defer func() {
		if authed {
			s.removeClient(cl)
		}
	}()
	for {
		conn.SetReadDeadline(time.Now().Add(readTimeout))
		if !sc.Scan() {
			return
		}
		var req Request
		if err := json.Unmarshal(sc.Bytes(), &req); err != nil {
			s.replyAndClose(cl, Response{Error: &Error{Code: CodeBadRequest, Message: err.Error()}})
			return
		}
		if !authed {
			var p HelloParams
			if req.Method != "hello" || json.Unmarshal(req.Params, &p) != nil ||
				subtle.ConstantTimeCompare([]byte(p.Token), []byte(s.cfg.Token)) != 1 {
				s.replyAndClose(cl, Response{ID: req.ID, Error: &Error{Code: CodeUnauthorized, Message: "invalid token"}})
				return
			}
			authed = true
			s.addClient(cl)
			s.reply(cl, Response{ID: req.ID, Result: map[string]any{"version": Version, "state": s.engine.State()}})
			continue
		}
		// Requests run concurrently so a slow latency test doesn't block pings.
		go func(req Request) {
			defer func() {
				// A method that panicked still answers, so the app does not wait for it.
				if value := recover(); value != nil {
					rec := logrec.PanicRecord(logrec.SourceCore, req.Method, value)
					s.publishLog(rec)
					s.reply(cl, Response{ID: req.ID, Error: &Error{Code: CodeInternal, Message: "internal error"}})
					if logrec.Repanic {
						panic(value)
					}
				}
			}()
			result, err := s.dispatch(req)
			resp := Response{ID: req.ID, Result: result}
			if err != nil {
				var ce *Error
				if !errors.As(err, &ce) {
					ce = &Error{Code: CodeBadRequest, Message: err.Error()}
				}
				resp.Error, resp.Result = ce, nil
			}
			s.reply(cl, resp)
		}(req)
	}
}

// replyAndClose flushes a final response through the writer before the connection closes.
func (s *Server) replyAndClose(c *client, r Response) {
	flushed := make(chan struct{})
	s.reply(c, r)
	s.reply(c, flushMarker(flushed))
	select {
	case <-flushed:
	case <-time.After(2 * time.Second):
	}
}

// flushMarker is queued after a message; the writer closes it instead of sending it.
type flushMarker chan struct{}

func (s *Server) reply(c *client, r any) {
	select {
	case c.send <- r:
	case <-c.done:
	}
}

func decode[T any](raw json.RawMessage) (T, error) {
	var v T
	if len(raw) == 0 {
		return v, nil
	}
	if err := json.Unmarshal(raw, &v); err != nil {
		return v, &Error{Code: CodeBadRequest, Message: err.Error()}
	}
	return v, nil
}

// Call runs a control method in this process, as if a client had sent it.
// Android's always-on VPN uses it to reconnect with the saved "start" request
// when the system starts the VPN service and no UI is running.
func (s *Server) Call(method string, params json.RawMessage) (any, error) {
	return s.dispatch(Request{Method: method, Params: params})
}

func (s *Server) dispatch(req Request) (any, error) {
	switch req.Method {
	case "ping":
		return "pong", nil
	case "state":
		return s.engine.State(), nil
	case "logging.get":
		return loggingSettings(), nil
	case "logging.set":
		params, err := decode[LoggingParams](req.Params)
		if err != nil {
			return nil, err
		}
		return setLogging(params)
	case "import":
		params, err := decode[ImportParams](req.Params)
		if err != nil {
			return nil, err
		}
		res, err := importer.Import(params.Text)
		if err != nil {
			return nil, importFailure(err, res)
		}
		return res, nil
	case "forms":
		return profile.Forms(), nil
	case "build_profile":
		params, err := decode[BuildProfileParams](req.Params)
		if err != nil {
			return nil, err
		}
		var built *profile.Profile
		if params.Profile != nil {
			// Editing: apply the values to a copy, then check the whole profile.
			cp := *params.Profile
			built = &cp
			err = built.Apply(params.Values)
			if err == nil {
				err = built.Validate()
			}
		} else {
			built, err = profile.FromValues(params.Protocol, params.Values)
		}
		if err == nil {
			err = checkVia(built)
		}
		if err != nil {
			return nil, badRequest(err)
		}
		return built, nil
	case "profile_values":
		params, err := decode[ProfileParams](req.Params)
		if err != nil || params.Profile == nil {
			return nil, &Error{Code: CodeBadRequest, Message: "a profile is required"}
		}
		return params.Profile.Values(), nil
	case "dnstt_scan":
		params, err := decode[DNSTTScanParams](req.Params)
		if err != nil {
			return nil, err
		}
		// The scan has to use the network as it is: through a running VPN it would measure the VPN.
		if st := s.engine.State().Status; st == engine.StatusRunning || st == engine.StatusStarting {
			return nil, &Error{Code: CodeScanConnected, Message: "disconnect the VPN first: a resolver scan has to use the network directly"}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		res, err := dnstt.Scan(ctx, dnstt.Config{Domain: params.Domain, PubKey: params.PubKey}, params.Resolvers, dnstt.Options{}, 6, 12*time.Second)
		if err != nil && res == nil {
			return nil, badRequest(err)
		}
		return res, nil
	case "warnings":
		params, err := decode[ProfileParams](req.Params)
		if err != nil || params.Profile == nil {
			return nil, &Error{Code: CodeBadRequest, Message: "a profile is required"}
		}
		return append([]profile.Warning{}, profile.WarningsFor(params.Profile)...), nil
	case "export_link":
		params, err := decode[ProfileParams](req.Params)
		if err != nil || params.Profile == nil {
			return nil, &Error{Code: CodeBadRequest, Message: "a profile is required"}
		}
		link, err := links.Export(params.Profile)
		if err != nil {
			return nil, &Error{Code: CodeBadRequest, Message: err.Error()}
		}
		return link, nil
	case "start":
		params, err := decode[StartParams](req.Params)
		if err != nil {
			return nil, err
		}
		if err := singbox.CheckDNS(params.DNS); err != nil {
			return nil, &Error{Code: CodeBadRequest, Message: "DNS: " + err.Error()}
		}
		if err := singbox.CheckDNSRelay(params.DNSRelay); err != nil {
			return nil, &Error{Code: CodeBadRequest, Message: "DNS relay: " + err.Error()}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		s.engine.ReportProgress(engine.StageNetworkCheck)
		if err := s.cfg.NetCheck(ctx); err != nil {
			s.engine.FailAt(engine.StageNetworkCheck, err)
			return nil, &Error{Code: CodeNoNetwork, Message: err.Error()}
		}
		opts := singbox.Options{
			Mode:            singbox.Mode(params.Mode),
			ListenPort:      params.ListenPort,
			Selected:        params.Selected,
			ProxyPrivate:    params.ProxyPrivate,
			SystemProxy:     params.SystemProxy,
			MTU:             params.MTU,
			NoIPv6:          params.NoIPv6,
			DNS:             params.DNS,
			DNSRelay:        params.DNSRelay,
			Failover:        params.Failover,
			IncludePackages: params.IncludePackages,
			ExcludePackages: params.ExcludePackages,
			TestURL:         params.TestURL,
			BypassOnly:      params.BypassOnly,
		}
		if params.Bypass != "" {
			// The app checked the lists when they were added; lines that cannot be used are skipped.
			opts.Bypass, _ = singbox.ParseBypassList(params.Bypass)
		}
		if err := s.ksPrepare(params, &opts); err != nil {
			return nil, err
		}
		if err := s.engine.Start(params.Profiles, opts); err != nil {
			s.ksStop()
			return nil, &Error{Code: CodeStartFailed, Message: err.Error()}
		}
		return s.engine.State(), nil
	case "exit_info":
		params, err := decode[ExitInfoParams](req.Params)
		if err != nil {
			return nil, err
		}
		info, err := s.exitInfo(context.Background(), params)
		if errors.Is(err, engine.ErrNoTunnel) {
			return nil, &Error{Code: CodeNotRunning, Message: err.Error()}
		}
		if err != nil {
			return nil, &Error{Code: CodeLookupFailed, Message: err.Error()}
		}
		return info, nil
	case "parse_bypass":
		params, err := decode[BypassParams](req.Params)
		if err != nil {
			return nil, err
		}
		list, issues := singbox.ParseBypassList(params.Text)
		return BypassReport{
			Entries: list.Count(), Ranges: len(list.CIDRs), Domains: list.Count() - len(list.CIDRs), Issues: issues,
		}, nil
	case "stop":
		err := s.engine.Stop()
		s.ksStop() // also lifts a block raised for a start that never got far
		return s.engine.State(), err
	case "select":
		params, err := decode[SelectParams](req.Params)
		if err != nil {
			return nil, err
		}
		if err := s.engine.Select(params.ID); err != nil {
			return nil, &Error{Code: CodeNotRunning, Message: err.Error()}
		}
		return s.engine.State(), nil
	case "subscribe":
		params, err := decode[subscription.Request](req.Params)
		if err != nil {
			return nil, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
		defer cancel()
		res, err := s.fetchSubscription(ctx, params)
		if err != nil {
			return nil, subscriptionError(err)
		}
		return res, nil
	case "test":
		params, err := decode[TestParams](req.Params)
		if err != nil {
			return nil, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		return s.engine.TestLatency(ctx, params.Profiles, params.URL)
	default:
		if res, handled, err := s.dispatchMesh(req); handled {
			return res, err
		}
		return nil, &Error{Code: CodeUnknownMethod, Message: fmt.Sprintf("unknown method %q", req.Method)}
	}
}

// rootPool returns the CA pool for HTTPS requests the server makes itself
// (subscriptions): the configured sing-box store, or nil for the system pool.
// fetchSubscription downloads a subscription directly or, as the request
// says, through the running VPN (for providers that are blocked here).
func (s *Server) fetchSubscription(ctx context.Context, req subscription.Request) (*subscription.Result, error) {
	urls := append([]string{req.URL}, req.FallbackURLs...)
	var firstErr error
	for _, u := range urls {
		if strings.TrimSpace(u) == "" {
			continue
		}
		one := req
		one.URL, one.FallbackURLs = u, nil
		res, err := s.fetchSubscriptionOne(ctx, one)
		if err == nil {
			return res, nil
		}
		if firstErr == nil {
			firstErr = err
		}
		// A wrong password is not cured by another address, and a key that is not a key by any.
		if errors.Is(err, subscription.ErrAuth) || errors.Is(err, subscription.ErrBadKey) || ctx.Err() != nil {
			return nil, err
		}
	}
	if firstErr == nil {
		return nil, fmt.Errorf("%w %q", subscription.ErrBadURL, req.URL)
	}
	if len(urls) > 1 {
		return nil, fmt.Errorf("%w (and %d backup addresses failed too)", firstErr, len(urls)-1)
	}
	return nil, firstErr
}

// fetchSubscriptionOne fetches one address: directly or through the running VPN, as the request says.
func (s *Server) fetchSubscriptionOne(ctx context.Context, req subscription.Request) (*subscription.Result, error) {
	pool := s.rootPool()
	switch req.Via {
	case subscription.ViaDirect:
		return subscription.Fetch(ctx, req, pool)
	case subscription.ViaTunnel:
		dial, err := s.engine.TunnelDialer()
		if err != nil {
			return nil, fmt.Errorf("this subscription is fetched through the VPN: %w", err)
		}
		return subscription.FetchVia(ctx, req, pool, dial)
	case subscription.ViaAuto:
		res, err := subscription.Fetch(ctx, req, pool)
		if err == nil || errors.Is(err, subscription.ErrAuth) {
			return res, err // a wrong password is not cured by another route
		}
		dial, derr := s.engine.TunnelDialer()
		if derr != nil {
			return nil, err
		}
		viaRes, viaErr := subscription.FetchVia(ctx, req, pool, dial)
		if viaErr != nil {
			return nil, fmt.Errorf("%w (through the VPN: %v)", err, viaErr)
		}
		return viaRes, nil
	}
	return nil, fmt.Errorf("unknown way to fetch a subscription: %q", req.Via)
}

func (s *Server) rootPool() *x509.CertPool {
	if s.cfg.CertificateStore == "" || s.cfg.CertificateStore == "system" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.pool == nil {
		store, err := certificate.NewStore(context.Background(), logger.NOP(), option.CertificateOptions{Store: s.cfg.CertificateStore})
		if err != nil {
			s.logf(logrec.LevelError, "certificate store %q: %v", s.cfg.CertificateStore, err)
			return nil
		}
		s.pool = store.Pool()
	}
	return s.pool
}

// checkVia reads the proxy under a WireGuard profile, so the editor can say what is wrong with it at once
// instead of when the tunnel is started.
func checkVia(prof *profile.Profile) error {
	if prof.WireGuard == nil || strings.TrimSpace(prof.WireGuard.Via) == "" {
		return nil
	}
	if _, err := importer.ParseLink(strings.TrimSpace(prof.WireGuard.Via)); err != nil {
		return fmt.Errorf("the proxy under WireGuard: %w", err)
	}
	return nil
}
