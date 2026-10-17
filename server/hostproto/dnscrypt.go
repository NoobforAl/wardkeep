package hostproto

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/netip"
	"strconv"
	"sync"
	"time"

	dc "github.com/ameshkov/dnscrypt/v2"
	"github.com/miekg/dns"
)

// The optional DNSCrypt resolver of the server. It answers DNS for whoever
// can reach its port (the VPN's users through the tunnel, or anyone on the
// internet if the firewall lets them), asks the upstream resolver, and keeps
// no logs. It is built on the DNSCrypt library the client uses; the long-term
// key comes from the server state, the short-term key and the certificate it
// signs are made here and replaced every DNSRotateEvery.

const (
	// A certificate outlives the rotation interval, so a client that has not yet
	// taken the new one still finds the old one valid until it asks again.
	dnsCryptCertTTL       = 14 * 24 * time.Hour
	defaultDNSRotateEvery = 7 * 24 * time.Hour
	dnsUpstreamTimeout    = 3 * time.Second
	// Per client address: a normal device asks a few dozen names a second at most.
	dnsRateQPS   = 60
	dnsRateBurst = 120
)

type dnsCryptServer struct {
	cfg      Config
	rc       dc.ResolverConfig
	upstream string
	limit    *rateLimiter
	logf     func(format string, args ...any)

	mu      sync.Mutex
	srv     *dc.Server
	tcp     net.Listener
	udp     *net.UDPConn
	serial  uint32
	stopped bool
	stop    chan struct{}
	wg      sync.WaitGroup
}

// Pool is empty: the resolver has no tunnel network of its own.
func (*dnsCryptServer) Pool() string { return "" }

func startDNSCrypt(cfg Config) (Server, error) {
	id := cfg.Env.DNSCrypt
	priv, err := hex.DecodeString(id.PrivateKey)
	if err != nil || len(priv) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("dnscrypt: the server has no valid DNSCrypt key")
	}
	if id.ProviderName == "" {
		return nil, fmt.Errorf("dnscrypt: the server has no provider name")
	}
	s := &dnsCryptServer{
		cfg: cfg,
		rc: dc.ResolverConfig{
			ProviderName: id.ProviderName, PublicKey: id.PublicKey, PrivateKey: id.PrivateKey,
			EsVersion: dc.XChacha20Poly1305, CertificateTTL: dnsCryptCertTTL,
		},
		upstream: upstreamResolver(id.Upstream),
		limit:    newRateLimiter(dnsRateQPS, dnsRateBurst),
		logf:     cfg.Logf,
		stop:     make(chan struct{}),
	}
	if s.logf == nil {
		s.logf = func(string, ...any) {}
	}
	if err := s.listen(); err != nil {
		return nil, err
	}
	every := cfg.DNSRotateEvery
	if every <= 0 {
		every = defaultDNSRotateEvery
	}
	s.wg.Add(1)
	go s.rotateLoop(every)
	return s, nil
}

// listen makes a new short-term key and certificate and serves them on TCP and UDP.
func (s *dnsCryptServer) listen() error {
	// The short-term key pair is made fresh (the ResolverConfig has none), and
	// the serial counts up, so a client takes the newest certificate.
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

	addr := net.JoinHostPort(s.cfg.DNSListen, strconv.Itoa(s.cfg.Port))
	l, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("dnscrypt: %w", err)
	}
	pc, err := net.ListenPacket("udp", addr)
	if err != nil {
		l.Close()
		return fmt.Errorf("dnscrypt: %w", err)
	}
	srv := &dc.Server{
		ProviderName: s.rc.ProviderName, ResolverCert: cert, Handler: s,
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	s.mu.Lock()
	s.srv, s.tcp, s.udp = srv, l, pc.(*net.UDPConn)
	s.mu.Unlock()
	go srv.ServeTCP(l)
	go srv.ServeUDP(pc.(*net.UDPConn))
	return nil
}

func mustKey(hexKey string) ed25519.PrivateKey {
	k, _ := hex.DecodeString(hexKey)
	return k
}

// shutdownListeners stops serving and frees the ports, waiting briefly for queries in flight.
func (s *dnsCryptServer) shutdownListeners() {
	s.mu.Lock()
	srv, tcp, udp := s.srv, s.tcp, s.udp
	s.srv, s.tcp, s.udp = nil, nil, nil
	s.mu.Unlock()
	if srv == nil {
		return
	}
	// The library does not close the sockets it is given: stop accepting first,
	// then let the queries in flight finish.
	tcp.Close()
	udp.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
}

// rotate replaces the short-term key and certificate. Clients that cached the
// old certificate ask for a new one when their queries stop being answered.
func (s *dnsCryptServer) rotate() error {
	s.shutdownListeners()
	if err := s.listen(); err != nil {
		return err
	}
	s.logf("dnscrypt: new short-term key and certificate")
	return nil
}

func (s *dnsCryptServer) rotateLoop(every time.Duration) {
	defer s.wg.Done()
	t := time.NewTimer(every)
	defer t.Stop()
	for {
		select {
		case <-s.stop:
			return
		case <-t.C:
		}
		if err := s.rotate(); err != nil {
			// The ports may be taken for a moment: try again soon rather than stay silent.
			s.logf("dnscrypt: rotating the certificate failed: %v (trying again in 30 s)", err)
			t.Reset(30 * time.Second)
			continue
		}
		t.Reset(every)
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
func (s *dnsCryptServer) ServeDNS(rw dc.ResponseWriter, q *dns.Msg) error {
	if ap, err := netip.ParseAddrPort(rw.RemoteAddr().String()); err == nil && !s.limit.allow(ap.Addr().Unmap()) {
		return nil // too many from one address: no answer
	}
	reply := func(code int) error {
		r := new(dns.Msg)
		r.SetRcode(q, code)
		return rw.WriteMsg(r)
	}
	if q.Opcode != dns.OpcodeQuery || len(q.Question) != 1 {
		return reply(dns.RcodeNotImplemented)
	}
	udp := &dns.Client{Net: "udp", Timeout: dnsUpstreamTimeout}
	r, _, err := udp.Exchange(q, s.upstream)
	if err != nil || (r != nil && r.Truncated) {
		tcp := &dns.Client{Net: "tcp", Timeout: dnsUpstreamTimeout}
		if r2, _, err2 := tcp.Exchange(q, s.upstream); err2 == nil {
			r, err = r2, nil
		}
	}
	if err != nil || r == nil {
		return reply(dns.RcodeServerFailure)
	}
	return rw.WriteMsg(r)
}

// upstreamResolver is the resolver the server asks: the configured "ip:port",
// the host's first nameserver, or 1.1.1.1.
func upstreamResolver(configured string) string {
	if configured != "" {
		if _, _, err := net.SplitHostPort(configured); err != nil {
			return net.JoinHostPort(configured, "53")
		}
		return configured
	}
	if cc, err := dns.ClientConfigFromFile("/etc/resolv.conf"); err == nil && len(cc.Servers) > 0 {
		return net.JoinHostPort(cc.Servers[0], cc.Port)
	}
	return "1.1.1.1:53"
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

func (l *rateLimiter) allow(a netip.Addr) bool {
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
	b := l.buckets[a]
	if b == nil {
		b = &bucket{tokens: l.burst, last: now}
		l.buckets[a] = b
	}
	b.tokens = min(l.burst, b.tokens+now.Sub(b.last).Seconds()*l.rate)
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}
