package client

// This file replaces upstream's dnstt-client/main.go: the same session (DNS transport, KCP, Noise, smux) as a
// library. Differences are listed in PATCHES.md.

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"sync"
	"sync/atomic"
	"time"

	utls "github.com/refraction-networking/utls"
	"github.com/xtaci/kcp-go/v5"
	"github.com/xtaci/smux"

	"github.com/NoobforAl/omnitun/third_party/dnstt/dns"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
	"github.com/NoobforAl/omnitun/third_party/dnstt/turbotunnel"
)

// smux streams will be closed after this much time without receiving data.
const idleTimeout = 2 * time.Minute

// DefaultUTLS is the TLS fingerprint distribution for DoH and DoT (upstream's default).
const DefaultUTLS = "4*random,3*Firefox_120,1*Firefox_105,3*Chrome_120,1*Chrome_102,1*iOS_14,1*iOS_13"

// DialFunc opens an outbound TCP connection. DoH and DoT resolvers are reached through it, so a caller can route
// the sockets (past a VPN, through a protected socket); nil dials directly.
type DialFunc func(ctx context.Context, network, addr string) (net.Conn, error)

// ListenPacketFunc opens the UDP socket that talks to a UDP resolver; remote is the resolver's "IP:port" (the socket
// is not bound to it, it only says where the socket's packets will go, so a caller can route them). nil opens an
// ordinary socket.
type ListenPacketFunc func(ctx context.Context, network, remote string) (net.PacketConn, error)

func defaultDial(ctx context.Context, network, addr string) (net.Conn, error) {
	return (&net.Dialer{}).DialContext(ctx, network, addr)
}

var logger atomic.Pointer[func(format string, args ...any)]

// SetLogf sets where the package logs (nothing by default). It is shared by every session.
func SetLogf(f func(format string, args ...any)) {
	if f == nil {
		logger.Store(nil)
		return
	}
	logger.Store(&f)
}

func logf(format string, args ...any) {
	if f := logger.Load(); f != nil {
		(*f)(format, args...)
	}
}

// Config describes a tunnel to a dnstt server.
type Config struct {
	// Domain is the DNS zone reserved for the tunnel, such as t.example.com.
	Domain string
	// PubKey is the server's public key (noise.KeyLen bytes).
	PubKey []byte
	// Resolver is where the DNS queries go: udp://IP:port, tls://host:port (DoT) or https://host/path (DoH). A UDP
	// resolver must be an IP address, so no name is looked up outside the tunnel's own sockets.
	Resolver string
	// UTLS is a weighted list of TLS fingerprints for DoH and DoT ("3*Firefox,2*Chrome"), "none" for the system's
	// TLS, empty for DefaultUTLS.
	UTLS string
	// Dial and ListenPacket open the sockets (see DialFunc and ListenPacketFunc).
	Dial         DialFunc
	ListenPacket ListenPacketFunc
}

// ParseResolver splits a resolver address into its scheme ("udp", "tls" or "https") and checks it.
func ParseResolver(s string) (scheme string, err error) {
	u, err := url.Parse(s)
	if err != nil || u.Host == "" {
		return "", fmt.Errorf("resolver %q is not an address (udp://IP:port, tls://host:port or https://host/path)", s)
	}
	switch u.Scheme {
	case "udp":
		if _, err := netip.ParseAddrPort(u.Host); err != nil {
			return "", fmt.Errorf("a UDP resolver must be an IP address and a port, like udp://1.1.1.1:53 (got %q)", s)
		}
	case "tls":
		if u.Port() == "" {
			return "", fmt.Errorf("a DoT resolver needs a port, like tls://dns.example:853 (got %q)", s)
		}
	case "https":
	default:
		return "", fmt.Errorf("resolver %q: use udp://, tls:// or https://", s)
	}
	return u.Scheme, nil
}

// dnsNameCapacity returns the number of bytes remaining for encoded data after
// including domain in a DNS name.
func dnsNameCapacity(domain dns.Name) int {
	// Names must be 255 octets or shorter in total length.
	// https://tools.ietf.org/html/rfc1035#section-2.3.4
	capacity := 255
	// Subtract the length of the null terminator.
	capacity -= 1
	for _, label := range domain {
		// Subtract the length of the label and the length octet.
		capacity -= len(label) + 1
	}
	// Each label may be up to 63 bytes long and requires 64 bytes to
	// encode.
	capacity = capacity * 63 / 64
	// Base32 expands every 5 bytes to 8.
	capacity = capacity * 5 / 8
	return capacity
}

// sampleUTLSDistribution parses a weighted uTLS Client Hello ID distribution
// string of the form "3*Firefox,2*Chrome,1*iOS", matches each label to a
// utls.ClientHelloID from utlsClientHelloIDMap, and randomly samples one
// utls.ClientHelloID from the distribution.
func sampleUTLSDistribution(spec string) (*utls.ClientHelloID, error) {
	weights, labels, err := parseWeightedList(spec)
	if err != nil {
		return nil, err
	}
	ids := make([]*utls.ClientHelloID, 0, len(labels))
	for _, label := range labels {
		var id *utls.ClientHelloID
		if label == "none" {
			id = nil
		} else {
			id = utlsLookup(label)
			if id == nil {
				return nil, fmt.Errorf("unknown TLS fingerprint %q", label)
			}
		}
		ids = append(ids, id)
	}
	return ids[sampleWeighted(weights)], nil
}

// transport opens the packet connection to the resolver and the address its packets go to.
func (cfg Config) transport(ctx context.Context) (net.Addr, net.PacketConn, error) {
	scheme, err := ParseResolver(cfg.Resolver)
	if err != nil {
		return nil, nil, err
	}
	u, _ := url.Parse(cfg.Resolver)
	dial := cfg.Dial
	if dial == nil {
		dial = defaultDial
	}
	spec := cfg.UTLS
	if spec == "" {
		spec = DefaultUTLS
	}
	id, err := sampleUTLSDistribution(spec)
	if err != nil {
		return nil, nil, fmt.Errorf("TLS fingerprints: %w", err)
	}
	switch scheme {
	case "udp":
		addr, err := net.ResolveUDPAddr("udp", u.Host) // an IP literal: nothing is looked up
		if err != nil {
			return nil, nil, err
		}
		listen := cfg.ListenPacket
		if listen == nil {
			listen = func(_ context.Context, network, _ string) (net.PacketConn, error) {
				return net.ListenPacket(network, "")
			}
		}
		pconn, err := listen(ctx, "udp", addr.String())
		if err != nil {
			return nil, nil, err
		}
		return addr, pconn, nil
	case "tls":
		dialTLS := func(ctx context.Context, network, addr string) (net.Conn, error) {
			if id != nil {
				return utlsDialContext(ctx, network, addr, nil, id, dial)
			}
			raw, err := dial(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			host, _, _ := net.SplitHostPort(addr)
			c := tls.Client(raw, &tls.Config{ServerName: host})
			if err := c.HandshakeContext(ctx); err != nil {
				raw.Close()
				return nil, err
			}
			return c, nil
		}
		pconn, err := NewTLSPacketConn(ctx, u.Host, dialTLS)
		return turbotunnel.DummyAddr{}, pconn, err
	default: // https
		var rt http.RoundTripper
		if id == nil {
			tr := http.DefaultTransport.(*http.Transport).Clone()
			tr.Proxy = nil // no proxy from the environment, like uTLS mode and DoT
			tr.DialContext = dial
			rt = tr
		} else {
			rt = NewUTLSRoundTripper(nil, id, dial)
		}
		pconn, err := NewHTTPPacketConn(rt, cfg.Resolver, 32)
		return turbotunnel.DummyAddr{}, pconn, err
	}
}

// Session is an open tunnel: a Noise-secured smux session over KCP over DNS.
type Session struct {
	conv  uint32
	conn  *kcp.UDPSession
	pconn net.PacketConn
	sess  *smux.Session
	once  sync.Once
}

// Open connects to the server through the resolver and completes the Noise handshake, which proves the whole
// path (resolver, the zone's delegation, the server and its key) works. ctx bounds the handshake.
func Open(ctx context.Context, cfg Config) (*Session, error) {
	domain, err := dns.ParseName(cfg.Domain)
	if err != nil {
		return nil, fmt.Errorf("invalid domain %+q: %v", cfg.Domain, err)
	}
	if len(cfg.PubKey) != noise.KeyLen {
		return nil, fmt.Errorf("the server key must be %d bytes", noise.KeyLen)
	}
	mtu := dnsNameCapacity(domain) - 8 - 1 - numPadding - 1 // clientid + padding length prefix + padding + data length prefix
	if mtu < 80 {
		return nil, fmt.Errorf("domain %s leaves only %d bytes for payload", domain, mtu)
	}
	remoteAddr, pconn, err := cfg.transport(ctx)
	if err != nil {
		return nil, err
	}
	pconn = NewDNSPacketConn(pconn, remoteAddr, domain)

	// Open a KCP conn on the PacketConn.
	conn, err := kcp.NewConn2(remoteAddr, nil, 0, 0, pconn)
	if err != nil {
		pconn.Close()
		return nil, fmt.Errorf("opening KCP conn: %v", err)
	}
	// Permit coalescing the payloads of consecutive sends.
	conn.SetStreamMode(true)
	// Disable the dynamic congestion window (limit only by the maximum of
	// local and remote static windows).
	conn.SetNoDelay(
		0, // default nodelay
		0, // default interval
		0, // default resend
		1, // nc=1 => congestion window off
	)
	conn.SetWindowSize(turbotunnel.QueueSize/2, turbotunnel.QueueSize/2)
	if rc := conn.SetMtu(mtu); !rc {
		conn.Close()
		pconn.Close()
		return nil, fmt.Errorf("KCP refused MTU %d", mtu)
	}
	s := &Session{conv: conn.GetConv(), conn: conn, pconn: pconn}
	logf("begin session %08x (MTU %d)", s.conv, mtu)

	// Put a Noise channel on top of the KCP conn. The handshake needs a round trip through the resolver; a
	// canceled ctx closes the connection, which ends it.
	type result struct {
		rw  io.ReadWriteCloser
		err error
	}
	done := make(chan result, 1)
	go func() {
		rw, err := noise.NewClient(conn, cfg.PubKey)
		done <- result{rw, err}
	}()
	var rw io.ReadWriteCloser
	select {
	case r := <-done:
		if r.err != nil {
			s.Close()
			return nil, fmt.Errorf("noise handshake: %w", r.err)
		}
		rw = r.rw
	case <-ctx.Done():
		s.Close()
		return nil, ctx.Err()
	}

	// Start a smux session on the Noise channel.
	smuxConfig := smux.DefaultConfig()
	smuxConfig.Version = 2
	smuxConfig.KeepAliveTimeout = idleTimeout
	smuxConfig.MaxStreamBuffer = 1 * 1024 * 1024 // default is 65536
	sess, err := smux.Client(rw, smuxConfig)
	if err != nil {
		s.Close()
		return nil, fmt.Errorf("opening smux session: %v", err)
	}
	s.sess = sess
	return s, nil
}

// Done is closed when the session ends: the resolver or the server went away, or Close was called.
func (s *Session) Done() <-chan struct{} { return s.sess.CloseChan() }

// Close ends the session.
func (s *Session) Close() error {
	s.once.Do(func() {
		logf("end session %08x", s.conv)
		if s.sess != nil {
			s.sess.Close()
		}
		s.conn.Close()
		s.pconn.Close()
	})
	return nil
}

// Forward carries one local TCP connection through a new stream to the server's upstream, and returns when both
// directions are done. It closes neither side's net.Conn; the caller closes local.
func (s *Session) Forward(local *net.TCPConn) error { return handle(local, s.sess, s.conv) }

func handle(local *net.TCPConn, sess *smux.Session, conv uint32) error {
	stream, err := sess.OpenStream()
	if err != nil {
		return fmt.Errorf("session %08x opening stream: %v", conv, err)
	}
	defer func() {
		logf("end stream %08x:%d", conv, stream.ID())
		stream.Close()
	}()
	logf("begin stream %08x:%d", conv, stream.ID())

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		_, err := io.Copy(stream, local)
		if err == io.EOF {
			// smux Stream.Write may return io.EOF.
			err = nil
		}
		if err != nil && !errors.Is(err, io.ErrClosedPipe) {
			logf("stream %08x:%d copy stream←local: %v", conv, stream.ID(), err)
		}
		local.CloseRead()
		stream.Close()
	}()
	go func() {
		defer wg.Done()
		_, err := io.Copy(local, stream)
		if err == io.EOF {
			// smux Stream.WriteTo may return io.EOF.
			err = nil
		}
		if err != nil && !errors.Is(err, io.ErrClosedPipe) {
			logf("stream %08x:%d copy local←stream: %v", conv, stream.ID(), err)
		}
		local.CloseWrite()
	}()
	wg.Wait()

	return nil
}

// Probe opens a session and closes it again, and reports how long the handshake took. It is the test of a
// resolver: a Noise handshake that completes went through the resolver to the server and back.
func Probe(ctx context.Context, cfg Config) (time.Duration, error) {
	start := time.Now()
	s, err := Open(ctx, cfg)
	if err != nil {
		return 0, err
	}
	d := time.Since(start)
	s.Close()
	return d, nil
}
