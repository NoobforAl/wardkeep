package hostproto

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/netip"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	dc "github.com/ameshkov/dnscrypt/v2"
	"github.com/miekg/dns"

	"github.com/NoobforAl/omnitun/core/protocols"
)

// The optional DNSCrypt resolver of the server. It is a resolver for the VPN's
// users, not for the internet:
//
//   - it listens on one address the operator names (a VPN tunnel address or
//     loopback), never on every interface, and does not start without it;
//   - it answers only sources in the VPN client ranges, loopback, the server's own
//     addresses and ranges the operator adds; everything else is dropped, certificate
//     requests included, and each source is rate limited;
//   - it asks a public resolver (1.1.1.1) unless the operator chooses another, and
//     the host's own resolver (which may know internal names) only when asked to;
//   - answers over UDP are cut to 1232 bytes, and ANY queries are refused.
//
// It is built on the DNSCrypt library the client uses; the long-term key comes
// from the server state, the short-term key and the certificate it signs are made
// here and replaced every DNSRotateEvery.

const (
	// A certificate outlives the rotation interval, so a client that has not yet
	// taken the new one still finds the old one valid until it asks again.
	dnsCryptCertTTL       = 14 * 24 * time.Hour
	defaultDNSRotateEvery = 7 * 24 * time.Hour
	dnsUpstreamTimeout    = 3 * time.Second
	// Per client address: a normal device asks a few dozen names a second at most.
	dnsRateQPS   = 60
	dnsRateBurst = 120
	// Requests for the certificate are rare: a client asks once in hours.
	dnsCertQPS   = 2
	dnsCertBurst = 6
	// The largest answer sent over UDP (the usual safe size without fragmenting).
	dnsMaxUDPAnswer = 1232
	udpSessionIdle  = 30 * time.Second
	udpSessionMax   = 4096
)

// defaultDNSUpstream is asked unless the operator chooses another resolver.
const defaultDNSUpstream = "1.1.1.1:53"

// VPNClientRanges are the networks the VPN servers give their clients; the
// resolver answers them.
var VPNClientRanges = mustPrefixes(
	"10.30.0.0/16", "10.31.0.0/16", "10.18.0.0/16", "10.19.0.0/16",
	protocols.WGPool6, protocols.AWGPool6, "fd18:0:0:1::/64", "fd19:0:0:1::/64",
)

func mustPrefixes(list ...string) []netip.Prefix {
	out := make([]netip.Prefix, len(list))
	for i, s := range list {
		out[i] = netip.MustParsePrefix(s)
	}
	return out
}

// gate decides who may ask, and how often.
type gate struct {
	query *rateLimiter
	cert  *rateLimiter

	mu     sync.Mutex
	static []netip.Prefix // loopback, VPN client ranges, the operator's ranges
	own    []netip.Prefix // the server's own addresses
	ownAt  time.Time
}

func newGate(extra []netip.Prefix) *gate {
	static := []netip.Prefix{netip.MustParsePrefix("127.0.0.0/8"), netip.MustParsePrefix("::1/128")}
	static = append(static, VPNClientRanges...)
	static = append(static, extra...)
	return &gate{
		static: static,
		query:  newRateLimiter(dnsRateQPS, dnsRateBurst),
		cert:   newRateLimiter(dnsCertQPS, dnsCertBurst),
	}
}

// permitted reports whether a source address may use the resolver.
func (g *gate) permitted(addr netip.Addr) bool {
	addr = addr.Unmap().WithZone("")
	g.mu.Lock()
	defer g.mu.Unlock()
	for _, p := range g.static {
		if p.Contains(addr) {
			return true
		}
	}
	if time.Since(g.ownAt) > 30*time.Second {
		g.own, g.ownAt = nil, time.Now()
		if addrs, err := net.InterfaceAddrs(); err == nil {
			for _, ad := range addrs {
				if ip, ok := netip.AddrFromSlice(ad.(*net.IPNet).IP); ok {
					ip = ip.Unmap()
					g.own = append(g.own, netip.PrefixFrom(ip, ip.BitLen()))
				}
			}
		}
	}
	for _, p := range g.own {
		if p.Contains(addr) {
			return true
		}
	}
	return false
}

type dnsCryptServer struct {
	cfg      Config
	rc       dc.ResolverConfig
	listen   netip.Addr
	upstream string
	gate     *gate
	logf     func(format string, args ...any)

	mu       sync.Mutex
	srv      *dc.Server
	tcp      net.Listener
	front    *udpFront
	internal string // the library's own UDP socket, behind the front
	serial   uint32
	stopped  bool
	stop     chan struct{}
	wg       sync.WaitGroup
}

// Pool is empty: the resolver has no tunnel network of its own.
func (*dnsCryptServer) Pool() string { return "" }

func startDNSCrypt(cfg Config) (Server, error) {
	id := cfg.Env.DNSCrypt
	listen, err := parseListen(id.Listen)
	if err != nil {
		return nil, fmt.Errorf("dnscrypt: %w (omnitun-server dnscrypt listen <ip>)", err)
	}
	extra, err := parseRanges(id.Allow)
	if err != nil {
		return nil, fmt.Errorf("dnscrypt: %w", err)
	}
	priv, err := hex.DecodeString(id.PrivateKey)
	if err != nil || len(priv) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("dnscrypt: the server has no valid DNSCrypt key")
	}
	if id.ProviderName == "" {
		return nil, fmt.Errorf("dnscrypt: the server has no provider name")
	}
	srv := &dnsCryptServer{
		cfg: cfg,
		rc: dc.ResolverConfig{
			ProviderName: id.ProviderName, PublicKey: id.PublicKey, PrivateKey: id.PrivateKey,
			EsVersion: dc.XChacha20Poly1305, CertificateTTL: dnsCryptCertTTL,
		},
		listen:   listen,
		upstream: upstreamResolver(id.Upstream),
		gate:     newGate(extra),
		logf:     cfg.Logf,
		stop:     make(chan struct{}),
	}
	if srv.logf == nil {
		srv.logf = func(string, ...any) {}
	}
	if err := srv.listenAll(); err != nil {
		return nil, err
	}
	every := cfg.DNSRotateEvery
	if every <= 0 {
		every = defaultDNSRotateEvery
	}
	srv.wg.Add(1)
	go srv.rotateLoop(every)
	return srv, nil
}

// parseListen accepts one specific address; the wildcard is refused.
func parseListen(text string) (netip.Addr, error) {
	if text == "" {
		return netip.Addr{}, fmt.Errorf("no address to listen on is set")
	}
	addr, err := netip.ParseAddr(text)
	if err != nil {
		return netip.Addr{}, fmt.Errorf("%q is not an IP address", text)
	}
	if addr.IsUnspecified() || addr.IsMulticast() {
		return netip.Addr{}, fmt.Errorf("%s would listen on every interface", addr)
	}
	return addr, nil
}

func parseRanges(list []string) ([]netip.Prefix, error) {
	var out []netip.Prefix
	for _, entry := range list {
		prefix, err := netip.ParsePrefix(entry)
		if err != nil {
			addr, err2 := netip.ParseAddr(entry)
			if err2 != nil {
				return nil, fmt.Errorf("%q is not an IP address or range", entry)
			}
			prefix = netip.PrefixFrom(addr, addr.BitLen())
		}
		if prefix.Bits() == 0 {
			return nil, fmt.Errorf("%s is every address", entry)
		}
		out = append(out, prefix.Masked())
	}
	return out, nil
}

// listenAll makes a new short-term key and certificate and serves them on TCP
// and UDP at the listen address. TCP connections from sources that may not ask
// are closed; UDP goes through a front socket that drops them (the library's own
// socket is on loopback behind it).
func (s *dnsCryptServer) listenAll() error {
	rc := s.rc
	rc.ResolverSk, rc.ResolverPk = "", ""
	cert, err := rc.CreateCert()
	if err != nil {
		return fmt.Errorf("dnscrypt: %w", err)
	}
	s.mu.Lock()
	if cert.Serial <= s.serial {
		cert.Serial = s.serial + 1
		cert.Sign(mustKey(s.rc.PrivateKey))
	}
	s.serial = cert.Serial
	s.mu.Unlock()

	port := strconv.Itoa(s.cfg.Port)
	ln, err := net.Listen("tcp", net.JoinHostPort(s.listen.String(), port))
	if err != nil {
		return fmt.Errorf("dnscrypt: %w", err)
	}
	outer, err := net.ListenUDP("udp", net.UDPAddrFromAddrPort(netip.AddrPortFrom(s.listen, uint16(s.cfg.Port)))) //nolint:gosec // G115: net.Listen above already rejected ports outside 0..65535
	if err != nil {
		ln.Close()
		return fmt.Errorf("dnscrypt: %w", err)
	}
	inner, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		ln.Close()
		outer.Close()
		return fmt.Errorf("dnscrypt: %w", err)
	}
	srv := &dc.Server{
		ProviderName: s.rc.ProviderName, ResolverCert: cert, Handler: s,
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	front := &udpFront{
		conn: outer, target: inner.LocalAddr().(*net.UDPAddr), inner: inner, gate: s.gate,
		magic: cert.ClientMagic, sessions: map[netip.AddrPort]*udpSession{}, done: make(chan struct{}),
	}
	s.mu.Lock()
	s.srv, s.tcp, s.front, s.internal = srv, ln, front, inner.LocalAddr().String()
	s.mu.Unlock()
	go func() { _ = srv.ServeTCP(&gatedListener{Listener: ln, gate: s.gate}) }()
	go func() { _ = srv.ServeUDP(inner) }()
	go front.run()
	return nil
}

func mustKey(hexKey string) ed25519.PrivateKey {
	k, _ := hex.DecodeString(hexKey)
	return k
}

// shutdownListeners stops serving and frees the ports, waiting briefly for queries in flight.
func (s *dnsCryptServer) shutdownListeners() {
	s.mu.Lock()
	srv, tcp, front := s.srv, s.tcp, s.front
	s.srv, s.tcp, s.front = nil, nil, nil
	s.mu.Unlock()
	if srv == nil {
		return
	}
	// The library does not close the sockets it is given: stop accepting first,
	// then let the queries in flight finish.
	tcp.Close()
	front.close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
	front.inner.Close()
}

// rotate replaces the short-term key and certificate. Clients that cached the
// old certificate ask for a new one when their queries stop being answered.
func (s *dnsCryptServer) rotate() error {
	s.shutdownListeners()
	if err := s.listenAll(); err != nil {
		return err
	}
	s.logf("dnscrypt: new short-term key and certificate")
	return nil
}

func (s *dnsCryptServer) rotateLoop(every time.Duration) {
	defer s.wg.Done()
	timer := time.NewTimer(every)
	defer timer.Stop()
	for {
		select {
		case <-s.stop:
			return
		case <-timer.C:
		}
		if err := s.rotate(); err != nil {
			// The ports may be taken for a moment: try again soon rather than stay silent.
			s.logf("dnscrypt: rotating the certificate failed: %v (trying again in 30 s)", err)
			timer.Reset(30 * time.Second)
			continue
		}
		timer.Reset(every)
	}
}

// Close stops the resolver.
func (s *dnsCryptServer) Close() error {
	s.mu.Lock()
	if s.stopped {
		s.mu.Unlock()
		return nil
	}
	s.stopped = true
	close(s.stop)
	s.mu.Unlock()
	s.wg.Wait()
	s.shutdownListeners()
	return nil
}

// ServeDNS answers one decrypted query: it asks the upstream resolver.
func (s *dnsCryptServer) ServeDNS(rw dc.ResponseWriter, req *dns.Msg) error {
	_, isUDP := rw.(*dc.UDPResponseWriter)
	if !isUDP { // UDP was checked and limited at the front, where the real source is known
		if ap, err := netip.ParseAddrPort(rw.RemoteAddr().String()); err != nil || !s.gate.permitted(ap.Addr()) || !s.gate.query.allow(ap.Addr().Unmap()) {
			return nil //nolint:nilerr // not a client, or too many: no answer
		}
	}
	reply := func(code int) error {
		r := new(dns.Msg)
		r.SetRcode(req, code)
		return rw.WriteMsg(r)
	}
	if req.Opcode != dns.OpcodeQuery || len(req.Question) != 1 {
		return reply(dns.RcodeNotImplemented)
	}
	if req.Question[0].Qtype == dns.TypeANY {
		return reply(dns.RcodeNotImplemented) // RFC 8482: the classic amplification query
	}
	udp := &dns.Client{Net: "udp", Timeout: dnsUpstreamTimeout}
	resp, _, err := udp.Exchange(req, s.upstream)
	if err != nil || (resp != nil && resp.Truncated) {
		tcp := &dns.Client{Net: "tcp", Timeout: dnsUpstreamTimeout}
		if r2, _, err2 := tcp.Exchange(req, s.upstream); err2 == nil {
			resp, err = r2, nil
		}
	}
	if err != nil || resp == nil {
		return reply(dns.RcodeServerFailure)
	}
	if isUDP && resp.Len() > dnsMaxUDPAnswer {
		resp.Truncate(dnsMaxUDPAnswer)
	}
	return rw.WriteMsg(resp)
}

// upstreamResolver is the resolver the server asks: the configured "ip" or
// "ip:port"; the host's own only when the operator asked for it ("system");
// otherwise the public 1.1.1.1. The host's /etc/resolv.conf is never the
// default: it often names a resolver for internal names.
func upstreamResolver(configured string) string {
	switch configured {
	case "":
		return defaultDNSUpstream
	case protocols.UpstreamSystem:
		if cc, err := dns.ClientConfigFromFile("/etc/resolv.conf"); err == nil && len(cc.Servers) > 0 {
			return net.JoinHostPort(cc.Servers[0], cc.Port)
		}
		return defaultDNSUpstream
	}
	if _, _, err := net.SplitHostPort(configured); err != nil {
		return net.JoinHostPort(configured, "53")
	}
	return configured
}

// gatedListener closes connections from sources that may not ask, before
// the DNSCrypt server sees them.
type gatedListener struct {
	net.Listener
	gate *gate
}

func (l *gatedListener) Accept() (net.Conn, error) {
	for {
		conn, err := l.Listener.Accept()
		if err != nil {
			return nil, err
		}
		ap, perr := netip.ParseAddrPort(conn.RemoteAddr().String())
		if perr != nil || !l.gate.permitted(ap.Addr()) || !l.gate.query.allow(ap.Addr().Unmap()) {
			conn.Close()
			continue
		}
		return conn, nil
	}
}

// udpFront is the socket clients talk to. It drops packets from sources that
// may not ask (and those that ask too often, the certificate request with a
// stricter limit) and passes the rest to the DNSCrypt server's own socket on
// loopback, one connected socket per client so the replies find their way back.
type udpFront struct {
	conn   *net.UDPConn
	target *net.UDPAddr
	inner  *net.UDPConn
	gate   *gate
	magic  [8]byte

	maxSessions int           // default udpSessionMax
	idle        time.Duration // default udpSessionIdle
	reads       atomic.Int64  // reads by the reply goroutines (tests watch it for spinning)

	mu       sync.Mutex
	sessions map[netip.AddrPort]*udpSession
	closed   bool
	done     chan struct{}
}

type udpSession struct {
	conn *net.UDPConn
	last time.Time
}

func (f *udpFront) close() {
	f.mu.Lock()
	if f.closed {
		f.mu.Unlock()
		return
	}
	f.closed = true
	close(f.done)
	for _, s := range f.sessions {
		s.conn.Close()
	}
	f.sessions = nil
	f.mu.Unlock()
	f.conn.Close()
}

func (f *udpFront) run() {
	buf := make([]byte, 65535)
	for {
		n, from, err := f.conn.ReadFromUDPAddrPort(buf)
		if err != nil {
			return
		}
		src := from.Addr().Unmap()
		if !f.gate.permitted(src) {
			continue
		}
		pkt := buf[:n]
		// A query in the current certificate's key starts with its client magic; anything
		// else is, at most, the certificate request, which is limited harder.
		if n < 8 || [8]byte(pkt[:8]) != f.magic {
			if !f.gate.cert.allow(src) {
				continue
			}
		} else if !f.gate.query.allow(src) {
			continue
		}
		sess := f.session(from)
		if sess == nil {
			continue
		}
		_, _ = sess.conn.Write(pkt)
	}
}

// session returns the connected socket for a client, making it (and the goroutine
// that sends the replies back) the first time.
func (f *udpFront) session(from netip.AddrPort) *udpSession {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.closed {
		return nil
	}
	now := time.Now()
	if s := f.sessions[from]; s != nil {
		s.last = now
		return s
	}
	maxSessions, idle := f.maxSessions, f.idle
	if maxSessions == 0 {
		maxSessions = udpSessionMax
	}
	if idle == 0 {
		idle = udpSessionIdle
	}
	if len(f.sessions) >= maxSessions {
		// Idle sessions go: the table forgets them and closes their sockets, which
		// ends their reply goroutines (a closed socket is not a timeout).
		for k, s := range f.sessions {
			if now.Sub(s.last) > idle {
				delete(f.sessions, k)
				s.conn.Close()
			}
		}
		if len(f.sessions) >= maxSessions {
			return nil
		}
	}
	upstream, err := net.DialUDP("udp", nil, f.target)
	if err != nil {
		return nil
	}
	s := &udpSession{conn: upstream, last: now}
	f.sessions[from] = s
	go f.reply(from, s, idle)
	return s
}

// reply sends what the DNSCrypt server answers a client back to it. It ends when
// the socket is closed (eviction, or the front closing), on any other read error,
// or when the session has been idle for a whole period; it never retries after an
// error that is not a timeout, and the goroutine closes its own socket on the way out.
func (f *udpFront) reply(from netip.AddrPort, sess *udpSession, idle time.Duration) {
	defer sess.conn.Close()
	buf := make([]byte, 65535)
	for {
		_ = sess.conn.SetReadDeadline(time.Now().Add(idle))
		n, err := sess.conn.Read(buf)
		f.reads.Add(1)
		if err == nil {
			_, _ = f.conn.WriteToUDPAddrPort(buf[:n], from)
			continue
		}
		var ne net.Error
		if errors.Is(err, net.ErrClosed) || !errors.As(err, &ne) || !ne.Timeout() {
			f.forget(from, sess)
			return
		}
		// A timeout: leave if the session is idle or no longer the client's current one.
		f.mu.Lock()
		current := f.sessions[from] == sess
		stop := f.closed || !current || time.Since(sess.last) >= idle
		if stop && current {
			delete(f.sessions, from)
		}
		f.mu.Unlock()
		if stop {
			return
		}
	}
}

// forget removes a session from the table if it is still the client's.
func (f *udpFront) forget(from netip.AddrPort, s *udpSession) {
	f.mu.Lock()
	if f.sessions[from] == s {
		delete(f.sessions, from)
	}
	f.mu.Unlock()
}

// rateLimiter is a token bucket per client address.
type rateLimiter struct {
	rate  float64
	burst float64

	mu      sync.Mutex
	buckets map[netip.Addr]*bucket
	swept   time.Time
}

type bucket struct {
	tokens float64
	last   time.Time
}

func newRateLimiter(perSecond, burst int) *rateLimiter {
	return &rateLimiter{rate: float64(perSecond), burst: float64(burst), buckets: map[netip.Addr]*bucket{}, swept: time.Now()}
}

func (l *rateLimiter) allow(addr netip.Addr) bool {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()
	if now.Sub(l.swept) > time.Minute {
		for k, b := range l.buckets {
			if now.Sub(b.last) > time.Minute {
				delete(l.buckets, k)
			}
		}
		l.swept = now
	}
	b := l.buckets[addr]
	if b == nil {
		b = &bucket{tokens: l.burst, last: now}
		l.buckets[addr] = b
	}
	b.tokens = min(l.burst, b.tokens+now.Sub(b.last).Seconds()*l.rate)
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}
