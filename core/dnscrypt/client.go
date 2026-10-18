package dnscrypt

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	dc "github.com/ameshkov/dnscrypt/v2"
	"github.com/ameshkov/dnscrypt/v2/xsecretbox"
	"github.com/miekg/dns"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/nacl/box"
)

// Dialer opens the connections to the resolver (or its relay). The app passes
// the tunnel's outbound here, so the queries leave through the VPN and the
// network between this device and the VPN server never sees the resolver.
type Dialer func(ctx context.Context, network, address string) (net.Conn, error)

// Errors of the DNSCrypt exchange.
var (
	// ErrBadResponse means the answer did not decrypt or did not match the query.
	ErrBadResponse = errors.New("dnscrypt: the resolver's answer is not valid")
	// ErrNotReady is what a Dialer returns while the way out (the tunnel) is not
	// there yet; it is not taken as a sign that UDP does not work.
	ErrNotReady = errors.New("dnscrypt: the way out is not ready")
	// ErrNeedIP means Anonymized DNSCrypt was asked for a resolver whose stamp has a host name, not an IP.
	ErrNeedIP = errors.New("dnscrypt: Anonymized DNSCrypt needs the resolver's IP address in its stamp")
)

const (
	defaultTimeout = 5 * time.Second
	maxUDPQuery    = 1252 // an encrypted query longer than this goes over TCP
	maxIdleTCP     = 2
	tcpIdleTime    = 20 * time.Second
)

// certRetryAfter is the pause before the certificate is fetched again after a
// failure, and the least age of a certificate that silence can make stale.
var certRetryAfter = 10 * time.Second

// session is a certificate of the resolver and the keys made for it.
type session struct {
	cert      *dc.Cert
	pk        [32]byte
	shared    [32]byte
	fetched   time.Time
	refreshAt time.Time
}

type idleConn struct {
	conn net.Conn
	at   time.Time
}

// Upstream talks DNSCrypt to one resolver, directly or through a relay
// (Anonymized DNSCrypt). It fetches and checks the resolver's certificate, and
// fetches it again before it expires. It is safe for concurrent use.
type Upstream struct {
	stamp   Stamp
	relay   *Stamp
	dial    Dialer
	tcpOnly bool
	timeout time.Duration
	logf    func(level, format string, args ...any)

	target string // address connected to: the relay, or the resolver
	header []byte // Anonymized DNSCrypt header, nil without a relay

	fetchMu sync.Mutex // one certificate fetch at a time
	mu      sync.Mutex
	sess    *session
	failAt  time.Time
	failErr error
	idle    []idleConn
	closed  bool
	// noUDPUntil (Unix nanoseconds) marks UDP as unusable for a while: the
	// tunnel's outbound may not carry it, and TCP is then used right away.
	noUDPUntil atomic.Int64
}

// UpstreamConfig sets up an Upstream.
type UpstreamConfig struct {
	Stamp Stamp
	// Relay, when set, makes the exchange Anonymized DNSCrypt.
	Relay *Stamp
	Dial  Dialer
	// TCPOnly keeps to TCP (Tor has no UDP).
	TCPOnly bool
	Timeout time.Duration
	Logf    func(level, format string, args ...any)
}

// NewUpstream checks the stamps and returns an Upstream. Nothing is sent yet.
func NewUpstream(c UpstreamConfig) (*Upstream, error) {
	if c.Stamp.Kind != KindDNSCrypt {
		return nil, badStamp("expected a DNSCrypt stamp, this one is %s", c.Stamp.Kind)
	}
	u := &Upstream{stamp: c.Stamp, relay: c.Relay, dial: c.Dial, tcpOnly: c.TCPOnly, timeout: c.Timeout, logf: c.Logf}
	if u.dial == nil {
		u.dial = func(ctx context.Context, network, address string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, network, address)
		}
	}
	if u.timeout <= 0 {
		u.timeout = defaultTimeout
	}
	u.target = c.Stamp.HostAddr()
	if c.Relay != nil {
		if c.Relay.Kind != KindRelay {
			return nil, badStamp("expected a relay stamp, this one is %s", c.Relay.Kind)
		}
		host, _, _ := splitHostPort(c.Stamp.Addr)
		ip, err := netip.ParseAddr(host)
		if err != nil {
			return nil, ErrNeedIP
		}
		u.header = relayHeader(netip.AddrPortFrom(ip, uint16(c.Stamp.Port)))
		u.target = c.Relay.HostAddr()
	}
	return u, nil
}

// Stamp returns the resolver's stamp.
func (u *Upstream) Stamp() Stamp { return u.stamp }

func (u *Upstream) log(level, format string, args ...any) {
	if u.logf != nil {
		u.logf(level, format, args...)
	}
}

// relayHeader is what Anonymized DNSCrypt puts in front of a packet: eight
// 0xff bytes, two zero bytes, the resolver's address as 16 bytes, its port.
func relayHeader(ap netip.AddrPort) []byte {
	h := make([]byte, 0, 28)
	h = append(h, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0, 0)
	a16 := ap.Addr().As16()
	h = append(h, a16[:]...)
	return binary.BigEndian.AppendUint16(h, ap.Port())
}

// Close drops the open connections.
func (u *Upstream) Close() {
	u.mu.Lock()
	u.closed = true
	idle := u.idle
	u.idle = nil
	u.mu.Unlock()
	for _, c := range idle {
		c.conn.Close()
	}
}

// Retry forgets a recent failure to fetch the certificate, so the next query
// tries again at once (the tunnel came up since).
func (u *Upstream) Retry() {
	u.mu.Lock()
	u.failErr = nil
	u.mu.Unlock()
	u.noUDPUntil.Store(0)
}

// Check fetches the certificate if there is none yet. A resolver whose key is
// not the one in the stamp fails here.
func (u *Upstream) Check(ctx context.Context) error {
	_, err := u.session(ctx)
	return err
}

// Exchange sends one DNS query (packed) and returns the packed answer.
func (u *Upstream) Exchange(ctx context.Context, query []byte) ([]byte, error) {
	if len(query) < 12 {
		return nil, errors.New("dnscrypt: query too short")
	}
	var lastErr error
	for range 2 {
		sess, err := u.session(ctx)
		if err != nil {
			return nil, err
		}
		resp, err := u.exchangeWith(ctx, sess, query)
		if err == nil {
			return resp, nil
		}
		lastErr = err
		if ctx.Err() != nil {
			break
		}
		// An answer that does not decrypt, or silence, may mean the resolver
		// rotated its certificate: look for a new one before trying again.
		u.markStale(sess)
		if !errors.Is(err, ErrBadResponse) && !isTimeout(err) {
			break
		}
	}
	return nil, lastErr
}

func isTimeout(err error) bool {
	var ne net.Error
	return errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &ne) && ne.Timeout())
}

func (u *Upstream) markStale(s *session) {
	u.mu.Lock()
	defer u.mu.Unlock()
	if u.sess == s && time.Since(s.fetched) > certRetryAfter {
		s.refreshAt = time.Time{}
	}
}

// session returns the current certificate session, fetching a new one when it
// is missing or due. When a refresh fails and the old certificate is still
// valid, the old one is kept.
func (u *Upstream) session(ctx context.Context) (*session, error) {
	u.mu.Lock()
	s := u.sess
	u.mu.Unlock()
	if s != nil && time.Now().Before(s.refreshAt) {
		return s, nil
	}
	u.fetchMu.Lock()
	defer u.fetchMu.Unlock()
	u.mu.Lock()
	s = u.sess
	if s != nil && time.Now().Before(s.refreshAt) {
		u.mu.Unlock()
		return s, nil
	}
	if u.failErr != nil && time.Since(u.failAt) < certRetryAfter {
		err := u.failErr
		u.mu.Unlock()
		if s != nil && time.Now().Before(time.Unix(int64(s.cert.NotAfter), 0)) {
			return s, nil
		}
		return nil, err
	}
	u.mu.Unlock()

	ns, err := u.fetchSession(ctx)
	u.mu.Lock()
	defer u.mu.Unlock()
	if err != nil {
		u.failErr, u.failAt = err, time.Now()
		if s != nil && time.Now().Before(time.Unix(int64(s.cert.NotAfter), 0)) {
			u.log("warn", "DNSCrypt: could not renew the certificate of %s: %v", u.stamp.Name(), err)
			return s, nil
		}
		return nil, err
	}
	u.failErr = nil
	u.sess = ns
	return ns, nil
}

// fetchSession asks the resolver for its certificates, keeps the newest one
// signed with the key from the stamp, and derives the shared key.
func (u *Upstream) fetchSession(ctx context.Context) (*session, error) {
	name := dns.Fqdn(u.stamp.ProviderName)
	q := new(dns.Msg)
	q.SetQuestion(name, dns.TypeTXT)
	packed, err := q.Pack()
	if err != nil {
		return nil, fmt.Errorf("dnscrypt: provider name %q: %w", u.stamp.ProviderName, err)
	}
	var resp *dns.Msg
	var lastErr error
	for _, tcp := range u.networks() {
		raw, err := u.roundTrip(ctx, tcp, packed, func(b []byte) (any, error) {
			m := new(dns.Msg)
			if err := m.Unpack(b); err != nil || m.Id != q.Id || !m.Response {
				return nil, ErrBadResponse
			}
			return m, nil
		})
		if err != nil {
			lastErr = err
			continue
		}
		m := raw.(*dns.Msg)
		if m.Truncated && !tcp && !u.tcpOnly {
			continue // too big for UDP: ask again over TCP
		}
		resp = m
		break
	}
	if resp == nil {
		if lastErr == nil {
			lastErr = errors.New("no answer")
		}
		return nil, fmt.Errorf("fetching the certificate of %s: %w", u.stamp.Name(), lastErr)
	}
	if resp.Rcode != dns.RcodeSuccess {
		return nil, fmt.Errorf("fetching the certificate of %s: %w", u.stamp.Name(), dc.ErrFailedToFetchCert)
	}
	var best *dc.Cert
	lastErr = nil
	for _, rr := range resp.Answer {
		txt, ok := rr.(*dns.TXT)
		if !ok {
			continue
		}
		cert, err := parseCertTXT(strings.Join(txt.Txt, ""), u.stamp.PublicKey)
		if err != nil {
			lastErr = err
			continue
		}
		if best == nil || cert.Serial > best.Serial || (cert.Serial == best.Serial && cert.EsVersion > best.EsVersion) {
			best = cert
		}
	}
	if best == nil {
		if lastErr == nil {
			lastErr = fmt.Errorf("no certificate for %q", u.stamp.ProviderName)
		}
		return nil, fmt.Errorf("the certificate of %s is not acceptable: %w", u.stamp.Name(), lastErr)
	}

	var sk [32]byte
	if _, err := io.ReadFull(rand.Reader, sk[:]); err != nil {
		return nil, err
	}
	pk, err := curve25519.X25519(sk[:], curve25519.Basepoint)
	if err != nil {
		return nil, err
	}
	s := &session{cert: best, fetched: time.Now()}
	copy(s.pk[:], pk)
	switch best.EsVersion {
	case dc.XChacha20Poly1305:
		s.shared, err = xsecretbox.SharedKey(sk, best.ResolverPk)
		if err != nil {
			return nil, err
		}
	case dc.XSalsa20Poly1305:
		box.Precompute(&s.shared, &best.ResolverPk, &sk)
	default:
		return nil, dc.ErrEsVersion
	}
	end := time.Unix(int64(best.NotAfter), 0)
	s.refreshAt = end.Add(-10 * time.Minute)
	if limit := time.Now().Add(6 * time.Hour); s.refreshAt.After(limit) {
		s.refreshAt = limit
	}
	u.log("info", "DNSCrypt: certificate of %s accepted (serial %d, %s, valid until %s)",
		u.stamp.Name(), best.Serial, best.EsVersion, end.Format(time.RFC3339))
	return s, nil
}

// parseCertTXT reads one certificate from the text of a TXT record and checks
// its dates and its signature against the provider's public key.
func parseCertTXT(txt string, providerKey []byte) (*dc.Cert, error) {
	raw := unescapeTXT(txt)
	cert := &dc.Cert{}
	if err := cert.Deserialize(raw); err != nil {
		return nil, err
	}
	if !cert.VerifyDate() {
		return nil, dc.ErrInvalidDate
	}
	if !cert.VerifySignature(providerKey) {
		return nil, dc.ErrInvalidCertSignature
	}
	return cert, nil
}

// unescapeTXT undoes the presentation escapes of a TXT string (\DDD, \t, \r, \n, \x).
func unescapeTXT(s string) []byte {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c != '\\' {
			out = append(out, c)
			continue
		}
		i++
		if i >= len(s) {
			break
		}
		switch {
		case i+2 < len(s) && isDigit(s[i]) && isDigit(s[i+1]) && isDigit(s[i+2]):
			out = append(out, (s[i]-'0')*100+(s[i+1]-'0')*10+(s[i+2]-'0'))
			i += 2
		case s[i] == 't':
			out = append(out, '\t')
		case s[i] == 'r':
			out = append(out, '\r')
		case s[i] == 'n':
			out = append(out, '\n')
		default:
			out = append(out, s[i])
		}
	}
	return out
}

func isDigit(b byte) bool { return b >= '0' && b <= '9' }

// networks lists the transports to try in order: false is UDP, true is TCP.
func (u *Upstream) networks() []bool {
	if u.tcpOnly || time.Now().UnixNano() < u.noUDPUntil.Load() {
		return []bool{true}
	}
	return []bool{false, true}
}

// exchangeWith encrypts one query, sends it, and decrypts the answer. It tries UDP
// first and switches to TCP when the answer is cut short or too large to ask for.
func (u *Upstream) exchangeWith(ctx context.Context, s *session, query []byte) ([]byte, error) {
	var lastErr error
	for _, tcp := range u.networks() {
		eq := dc.EncryptedQuery{EsVersion: s.cert.EsVersion, ClientMagic: s.cert.ClientMagic, ClientPk: s.pk}
		// Encrypt pads in place, so it gets its own copy.
		enc, err := eq.Encrypt(append(make([]byte, 0, len(query)+300), query...), s.shared)
		if err != nil {
			return nil, err
		}
		if !tcp && len(enc) > maxUDPQuery {
			continue
		}
		raw, err := u.roundTrip(ctx, tcp, enc, func(b []byte) (any, error) {
			er := dc.EncryptedResponse{EsVersion: s.cert.EsVersion}
			plain, err := er.Decrypt(b, s.shared)
			if err != nil || !bytes.Equal(er.Nonce[:12], eq.Nonce[:12]) || len(plain) < 12 || plain[0] != query[0] || plain[1] != query[1] {
				return nil, ErrBadResponse
			}
			return plain, nil
		})
		if err != nil {
			lastErr = err
			continue
		}
		plain := raw.([]byte)
		if !tcp && !u.tcpOnly && plain[2]&0x02 != 0 {
			lastErr = errTruncated
			continue
		}
		return plain, nil
	}
	if lastErr == errTruncated {
		return nil, errors.New("dnscrypt: the answer was cut short")
	}
	return nil, lastErr
}

var errTruncated = errors.New("truncated")

// roundTrip sends payload (behind the relay header, if any) and returns what
// accept makes of the reply. accept returns ErrBadResponse for a reply that is
// not ours; over UDP such replies are skipped until the deadline.
func (u *Upstream) roundTrip(ctx context.Context, tcp bool, payload []byte, accept func([]byte) (any, error)) (any, error) {
	ctx, cancel := context.WithTimeout(ctx, u.timeout)
	defer cancel()
	frame := make([]byte, 0, len(u.header)+len(payload))
	frame = append(frame, u.header...)
	frame = append(frame, payload...)

	if !tcp {
		conn, err := u.dial(ctx, "udp", u.target)
		if err != nil {
			if ctx.Err() == nil && !errors.Is(err, ErrNotReady) {
				// Not a timeout: this path does not carry UDP (Tor, some proxies).
				u.noUDPUntil.Store(time.Now().Add(5 * time.Minute).UnixNano())
			}
			return nil, err
		}
		defer conn.Close()
		deadline, _ := ctx.Deadline()
		_ = conn.SetDeadline(deadline)
		stop := context.AfterFunc(ctx, func() { _ = conn.SetDeadline(time.Unix(1, 0)) })
		defer stop()
		if _, err := conn.Write(frame); err != nil {
			return nil, err
		}
		buf := make([]byte, 4096)
		for range 4 {
			n, err := conn.Read(buf)
			if err != nil {
				return nil, err
			}
			if v, err := accept(append([]byte(nil), buf[:n]...)); err == nil {
				return v, nil
			}
		}
		return nil, ErrBadResponse
	}

	for try := 0; ; try++ {
		conn, reused, err := u.tcpConn(ctx)
		if err != nil {
			return nil, err
		}
		v, err := u.tcpExchange(ctx, conn, frame, accept)
		if err == nil {
			u.putConn(conn)
			return v, nil
		}
		conn.Close()
		// A connection that sat idle may have been closed by the other end.
		if reused && try == 0 && ctx.Err() == nil && !errors.Is(err, ErrBadResponse) {
			continue
		}
		return nil, err
	}
}

func (u *Upstream) tcpExchange(ctx context.Context, conn net.Conn, frame []byte, accept func([]byte) (any, error)) (any, error) {
	deadline, _ := ctx.Deadline()
	_ = conn.SetDeadline(deadline)
	stop := context.AfterFunc(ctx, func() { _ = conn.SetDeadline(time.Unix(1, 0)) })
	defer stop()
	out := make([]byte, 2, 2+len(frame))
	binary.BigEndian.PutUint16(out, uint16(len(frame)))
	out = append(out, frame...)
	if _, err := conn.Write(out); err != nil {
		return nil, err
	}
	var l [2]byte
	if _, err := io.ReadFull(conn, l[:]); err != nil {
		return nil, err
	}
	buf := make([]byte, binary.BigEndian.Uint16(l[:]))
	if _, err := io.ReadFull(conn, buf); err != nil {
		return nil, err
	}
	return accept(buf)
}

// tcpConn returns an idle connection or opens one; reused tells which.
func (u *Upstream) tcpConn(ctx context.Context) (conn net.Conn, reused bool, err error) {
	u.mu.Lock()
	for len(u.idle) > 0 {
		c := u.idle[len(u.idle)-1]
		u.idle = u.idle[:len(u.idle)-1]
		if time.Since(c.at) > tcpIdleTime {
			c.conn.Close()
			continue
		}
		u.mu.Unlock()
		return c.conn, true, nil
	}
	u.mu.Unlock()
	conn, err = u.dial(ctx, "tcp", u.target)
	return conn, false, err
}

func (u *Upstream) putConn(c net.Conn) {
	u.mu.Lock()
	if u.closed || len(u.idle) >= maxIdleTCP {
		u.mu.Unlock()
		c.Close()
		return
	}
	u.idle = append(u.idle, idleConn{conn: c, at: time.Now()})
	u.mu.Unlock()
}
