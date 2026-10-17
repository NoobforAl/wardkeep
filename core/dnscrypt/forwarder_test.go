package dnscrypt

import (
	"context"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/netip"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	dc "github.com/ameshkov/dnscrypt/v2"
	"github.com/miekg/dns"
)

// testResolver is the library's DNSCrypt server on loopback, answering every
// A query with 192.0.2.1 and every TXT query with a long answer.
type testResolver struct {
	addr    string // "127.0.0.1:port", TCP and UDP
	stamp   string
	cfg     dc.ResolverConfig
	queries atomic.Int64
	server  *dc.Server
	tcp     net.Listener
	udp     *net.UDPConn
}

type resolverHandler struct{ r *testResolver }

func (h resolverHandler) ServeDNS(rw dc.ResponseWriter, q *dns.Msg) error {
	h.r.queries.Add(1)
	m := new(dns.Msg)
	m.SetReply(q)
	if len(q.Question) == 1 {
		switch q.Question[0].Qtype {
		case dns.TypeA:
			m.Answer = append(m.Answer, &dns.A{Hdr: dns.RR_Header{Name: q.Question[0].Name, Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: 60}, A: net.ParseIP("192.0.2.1")})
		case dns.TypeTXT:
			// A long answer, to see UDP truncation and the TCP retry.
			for range 40 {
				m.Answer = append(m.Answer, &dns.TXT{Hdr: dns.RR_Header{Name: q.Question[0].Name, Rrtype: dns.TypeTXT, Class: dns.ClassINET, Ttl: 60}, Txt: []string{"0123456789012345678901234567890123456789012345678901234567890123456789"}})
			}
		}
	}
	return rw.WriteMsg(m)
}

func newTestResolver(t *testing.T, es dc.CryptoConstruction) *testResolver {
	t.Helper()
	r := &testResolver{}
	cfg, err := dc.GenerateResolverConfig("example.test", nil)
	if err != nil {
		t.Fatal(err)
	}
	cfg.EsVersion = es
	cert, err := cfg.CreateCert()
	if err != nil {
		t.Fatal(err)
	}
	r.cfg = cfg
	l, pc := listenBoth(t)
	r.addr = l.Addr().String()
	r.tcp, r.udp = l, pc
	r.server = &dc.Server{ProviderName: cfg.ProviderName, ResolverCert: cert, Handler: resolverHandler{r}}
	go r.server.ServeTCP(l)
	go r.server.ServeUDP(pc)
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		r.server.Shutdown(ctx)
	})
	st, err := cfg.CreateStamp(r.addr)
	if err != nil {
		t.Fatal(err)
	}
	r.stamp = st.String()
	return r
}

// listenBoth opens a TCP listener and a UDP socket on the same loopback port.
func listenBoth(t *testing.T) (net.Listener, *net.UDPConn) {
	t.Helper()
	for range 50 {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		pc, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: l.Addr().(*net.TCPAddr).Port})
		if err == nil {
			t.Cleanup(func() { l.Close(); pc.Close() })
			return l, pc
		}
		l.Close()
	}
	t.Fatal("no loopback port free for both TCP and UDP")
	return nil, nil
}

// testRelay is an Anonymized DNSCrypt relay: it strips the header and passes
// the rest on to the address inside it.
type testRelay struct {
	addr string
	hits atomic.Int64
}

func splitRelay(p []byte) (target string, payload []byte, ok bool) {
	if len(p) < 28 {
		return "", nil, false
	}
	for i := 0; i < 8; i++ {
		if p[i] != 0xff {
			return "", nil, false
		}
	}
	if p[8] != 0 || p[9] != 0 {
		return "", nil, false
	}
	var a16 [16]byte
	copy(a16[:], p[10:26])
	ap := netip.AddrPortFrom(netip.AddrFrom16(a16).Unmap(), binary.BigEndian.Uint16(p[26:28]))
	return ap.String(), p[28:], true
}

func startRelay(t *testing.T) *testRelay {
	t.Helper()
	r := &testRelay{}
	l, pc := listenBoth(t)
	r.addr = l.Addr().String()
	go func() {
		buf := make([]byte, 65535)
		for {
			n, from, err := pc.ReadFromUDP(buf)
			if err != nil {
				return
			}
			p := append([]byte(nil), buf[:n]...)
			go func() {
				target, payload, ok := splitRelay(p)
				if !ok {
					return
				}
				r.hits.Add(1)
				c, err := net.Dial("udp", target)
				if err != nil {
					return
				}
				defer c.Close()
				c.SetDeadline(time.Now().Add(3 * time.Second))
				c.Write(payload)
				rb := make([]byte, 65535)
				n, err := c.Read(rb)
				if err == nil {
					pc.WriteToUDP(rb[:n], from)
				}
			}()
		}
	}()
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			go func() {
				defer c.Close()
				for {
					var lb [2]byte
					if _, err := io.ReadFull(c, lb[:]); err != nil {
						return
					}
					p := make([]byte, binary.BigEndian.Uint16(lb[:]))
					if _, err := io.ReadFull(c, p); err != nil {
						return
					}
					target, payload, ok := splitRelay(p)
					if !ok {
						return
					}
					r.hits.Add(1)
					up, err := net.Dial("tcp", target)
					if err != nil {
						return
					}
					out := binary.BigEndian.AppendUint16(nil, uint16(len(payload)))
					up.SetDeadline(time.Now().Add(3 * time.Second))
					up.Write(append(out, payload...))
					var rl [2]byte
					if _, err := io.ReadFull(up, rl[:]); err != nil {
						up.Close()
						return
					}
					rb := make([]byte, binary.BigEndian.Uint16(rl[:]))
					_, err = io.ReadFull(up, rb)
					up.Close()
					if err != nil {
						return
					}
					c.Write(append(binary.BigEndian.AppendUint16(nil, uint16(len(rb))), rb...))
				}
			}()
		}
	}()
	return r
}

// dialLog is a Dialer that records where it was asked to connect.
type dialLog struct {
	mu      sync.Mutex
	targets []string
	nets    []string
}

func (d *dialLog) dial(ctx context.Context, network, address string) (net.Conn, error) {
	d.mu.Lock()
	d.targets = append(d.targets, address)
	d.nets = append(d.nets, network)
	d.mu.Unlock()
	var nd net.Dialer
	return nd.DialContext(ctx, network, address)
}

func query(t *testing.T, network, addr, name string, qtype uint16) *dns.Msg {
	t.Helper()
	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), qtype)
	m.SetEdns0(4096, false)
	c := &dns.Client{Net: network, Timeout: 5 * time.Second}
	r, _, err := c.Exchange(m, addr)
	if err != nil {
		t.Fatalf("%s query for %s: %v", network, name, err)
	}
	return r
}

func startForwarder(t *testing.T, cfg ForwarderConfig) *Forwarder {
	t.Helper()
	f, err := NewForwarder(cfg)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { f.Close() })
	return f
}

func firstA(t *testing.T, r *dns.Msg) string {
	t.Helper()
	if r.Rcode != dns.RcodeSuccess || len(r.Answer) == 0 {
		t.Fatalf("no answer: rcode %s, %d records", dns.RcodeToString[r.Rcode], len(r.Answer))
	}
	a, ok := r.Answer[0].(*dns.A)
	if !ok {
		t.Fatalf("answer is %T", r.Answer[0])
	}
	return a.A.String()
}

func TestForwarderAnswersThroughDNSCrypt(t *testing.T) {
	for name, es := range map[string]dc.CryptoConstruction{"XSalsa20Poly1305": dc.XSalsa20Poly1305, "XChacha20Poly1305": dc.XChacha20Poly1305} {
		t.Run(name, func(t *testing.T) {
			res := newTestResolver(t, es)
			f := startForwarder(t, ForwarderConfig{Stamp: res.stamp})
			if err := f.Check(context.Background()); err != nil {
				t.Fatal(err)
			}
			if got := firstA(t, query(t, "udp", f.Addr(), "example.org", dns.TypeA)); got != "192.0.2.1" {
				t.Errorf("udp answer = %s", got)
			}
			if got := firstA(t, query(t, "tcp", f.Addr(), "Example.ORG", dns.TypeA)); got != "192.0.2.1" {
				t.Errorf("tcp answer = %s", got)
			}
			// The second one was the same question (case aside): served from the cache.
			if q := res.queries.Load(); q != 1 {
				t.Errorf("the resolver saw %d queries, want 1 (the second came from the cache)", q)
			}
			query(t, "udp", f.Addr(), "other.example.org", dns.TypeA)
			if q := res.queries.Load(); q != 2 {
				t.Errorf("the resolver saw %d queries, want 2", q)
			}
			st := f.Stats()
			if st.Queries != 3 || st.Answered != 2 || st.CacheHits != 1 || st.Failed != 0 || st.LastError != "" || st.LastOK.IsZero() {
				t.Errorf("stats = %+v", st)
			}
			if f.Resolver() != "example.test" || f.Anonymized() {
				t.Errorf("resolver %q anonymized %v", f.Resolver(), f.Anonymized())
			}
		})
	}
}

func TestCacheCanBeTurnedOff(t *testing.T) {
	res := newTestResolver(t, dc.XChacha20Poly1305)
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp, CacheEntries: -1})
	query(t, "udp", f.Addr(), "example.org", dns.TypeA)
	query(t, "udp", f.Addr(), "example.org", dns.TypeA)
	if q := res.queries.Load(); q != 2 {
		t.Errorf("the resolver saw %d queries, want 2", q)
	}
}

func TestLongAnswerIsTruncatedOnUDPAndWholeOnTCP(t *testing.T) {
	res := newTestResolver(t, dc.XSalsa20Poly1305)
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp})

	m := new(dns.Msg)
	m.SetQuestion("big.example.org.", dns.TypeTXT) // no EDNS: 512 bytes
	r, _, err := (&dns.Client{Net: "udp", Timeout: 5 * time.Second}).Exchange(m, f.Addr())
	if err != nil {
		t.Fatal(err)
	}
	if !r.Truncated {
		t.Errorf("a 3 KB answer to a plain UDP query was not marked truncated (%d records)", len(r.Answer))
	}
	if n := len(query(t, "tcp", f.Addr(), "big.example.org", dns.TypeTXT).Answer); n != 40 {
		t.Errorf("over TCP got %d records, want 40", n)
	}
	if n := len(query(t, "udp", f.Addr(), "big2.example.org", dns.TypeTXT).Answer); n != 40 {
		t.Errorf("over UDP with EDNS 4096 got %d records, want 40", n)
	}
}

func TestWrongProviderKeyIsRejected(t *testing.T) {
	res := newTestResolver(t, dc.XChacha20Poly1305)
	// The same resolver, but a stamp with another provider key: a man in the
	// middle that answers with its own certificate looks exactly like this.
	other, err := dc.GenerateResolverConfig("example.test", nil)
	if err != nil {
		t.Fatal(err)
	}
	st, err := ParseStamp(res.stamp)
	if err != nil {
		t.Fatal(err)
	}
	wrong, _ := dc.HexDecodeKey(other.PublicKey)
	st.PublicKey = wrong
	f := startForwarder(t, ForwarderConfig{Stamp: st.String()})

	err = f.Check(context.Background())
	if err == nil {
		t.Fatal("the certificate signed with a different key was accepted")
	}
	if !errors.Is(err, dc.ErrInvalidCertSignature) {
		t.Errorf("error = %v, want the invalid signature error", err)
	}
	r := query(t, "udp", f.Addr(), "example.org", dns.TypeA)
	if r.Rcode != dns.RcodeServerFailure || len(r.Answer) != 0 {
		t.Errorf("a query answered with rcode %s and %d records; want SERVFAIL", dns.RcodeToString[r.Rcode], len(r.Answer))
	}
	if res.queries.Load() != 0 {
		t.Errorf("the resolver was sent %d queries although its certificate was refused", res.queries.Load())
	}
	if s := f.Stats(); s.Failed == 0 || s.LastError == "" {
		t.Errorf("stats = %+v, want the failure recorded", s)
	}
}

func TestAnonymizedThroughARelay(t *testing.T) {
	res := newTestResolver(t, dc.XChacha20Poly1305)
	relay := startRelay(t)
	log := &dialLog{}
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp, Relay: relay.addr, Dial: log.dial})
	if !f.Anonymized() {
		t.Error("Anonymized() = false")
	}
	if got := firstA(t, query(t, "udp", f.Addr(), "example.org", dns.TypeA)); got != "192.0.2.1" {
		t.Errorf("answer = %s", got)
	}
	// A long answer to a query without EDNS is cut short by the resolver, so
	// the exchange falls back to TCP, through the relay too; the client asks
	// again over TCP and gets the whole answer.
	m := new(dns.Msg)
	m.SetQuestion("big.example.org.", dns.TypeTXT)
	if _, _, err := (&dns.Client{Net: "udp", Timeout: 5 * time.Second}).Exchange(m, f.Addr()); err != nil {
		t.Fatal(err)
	}
	if n := len(query(t, "tcp", f.Addr(), "big.example.org", dns.TypeTXT).Answer); n != 40 {
		t.Errorf("got %d records, want 40", n)
	}
	log.mu.Lock()
	defer log.mu.Unlock()
	if len(log.targets) == 0 {
		t.Fatal("nothing was dialed")
	}
	for _, target := range log.targets {
		if target != relay.addr {
			t.Errorf("a connection was opened to %s; everything must go to the relay %s", target, relay.addr)
		}
	}
	if relay.hits.Load() < 3 {
		t.Errorf("the relay passed on %d packets, want at least 3 (certificate, query, TCP retry)", relay.hits.Load())
	}
	sawTCP := false
	for _, n := range log.nets {
		sawTCP = sawTCP || n == "tcp"
	}
	if !sawTCP {
		t.Error("no TCP connection to the relay")
	}
}

func TestRelayWithoutResolverIPIsRefused(t *testing.T) {
	st := Stamp{Kind: KindDNSCrypt, Addr: "resolver.example.org:443", PublicKey: make([]byte, 32), ProviderName: "2.dnscrypt-cert.x"}
	_, err := NewForwarder(ForwarderConfig{Stamp: st.String(), Relay: "203.0.113.7:443"})
	if !errors.Is(err, ErrNeedIP) {
		t.Errorf("error = %v, want ErrNeedIP", err)
	}
	if _, err := NewForwarder(ForwarderConfig{Stamp: stampCFDoH}); err == nil {
		t.Error("a DoH stamp was accepted by the DNSCrypt forwarder")
	}
	if _, err := NewForwarder(ForwarderConfig{Stamp: stampQuad9, Relay: stampQuad9}); err == nil {
		t.Error("a resolver stamp was accepted as a relay")
	}
}

func TestTCPOnlyNeverOpensUDP(t *testing.T) {
	res := newTestResolver(t, dc.XSalsa20Poly1305)
	log := &dialLog{}
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp, Dial: log.dial, TCPOnly: true})
	for _, name := range []string{"a.example.org", "b.example.org", "c.example.org"} {
		if got := firstA(t, query(t, "udp", f.Addr(), name, dns.TypeA)); got != "192.0.2.1" {
			t.Errorf("answer = %s", got)
		}
	}
	log.mu.Lock()
	defer log.mu.Unlock()
	for _, n := range log.nets {
		if n != "tcp" {
			t.Errorf("a %s socket was opened", n)
		}
	}
	// The connection is kept for the next query: three queries and the
	// certificate do not need four connections.
	if len(log.nets) > 2 {
		t.Errorf("%d TCP connections for 4 exchanges, want them reused", len(log.nets))
	}
}

// An unreachable resolver means SERVFAIL, quickly, and never a plain-DNS answer.
func TestUnreachableResolverFailsClosedAndInflightIsLimited(t *testing.T) {
	res := newTestResolver(t, dc.XChacha20Poly1305)
	release := make(chan struct{})
	dial := func(ctx context.Context, network, address string) (net.Conn, error) {
		select {
		case <-release:
		case <-ctx.Done():
		}
		return nil, errors.New("no route to the resolver")
	}
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp, Dial: dial, MaxInflight: 2, Timeout: 2 * time.Second})

	out := make(chan int, 6)
	for i := 0; i < 6; i++ {
		go func(i int) {
			m := new(dns.Msg)
			m.SetQuestion(dns.Fqdn("host"+string(rune('a'+i))+".example.org"), dns.TypeA)
			r, _, err := (&dns.Client{Net: "udp", Timeout: 10 * time.Second}).Exchange(m, f.Addr())
			if err != nil {
				out <- -1
				return
			}
			out <- r.Rcode
		}(i)
	}
	// Two queries wait for the resolver; the other four are turned away at once.
	quick := 0
	deadline := time.After(1500 * time.Millisecond)
	for quick < 4 {
		select {
		case rcode := <-out:
			if rcode != dns.RcodeServerFailure {
				t.Fatalf("rcode %d, want SERVFAIL", rcode)
			}
			quick++
		case <-deadline:
			t.Fatalf("only %d queries were turned away quickly, want 4", quick)
		}
	}
	close(release)
	for i := 0; i < 2; i++ {
		select {
		case rcode := <-out:
			if rcode != dns.RcodeServerFailure {
				t.Errorf("rcode %d, want SERVFAIL", rcode)
			}
		case <-time.After(10 * time.Second):
			t.Fatal("a waiting query never got its SERVFAIL")
		}
	}
	if res.queries.Load() != 0 {
		t.Error("the resolver was reached although every dial failed")
	}
	if s := f.Stats(); s.Failed != 6 || s.Answered != 0 {
		t.Errorf("stats = %+v, want 6 failures", s)
	}
}

func TestMalformedPacketsGetNoAnswerAndOtherOpcodesAreRefused(t *testing.T) {
	res := newTestResolver(t, dc.XChacha20Poly1305)
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp})
	c, err := net.Dial("udp", f.Addr())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	c.Write([]byte{1, 2, 3})
	c.SetReadDeadline(time.Now().Add(300 * time.Millisecond))
	if n, err := c.Read(make([]byte, 512)); err == nil {
		t.Errorf("garbage got a %d byte answer", n)
	}
	m := new(dns.Msg)
	m.SetQuestion("example.org.", dns.TypeA)
	m.Opcode = dns.OpcodeNotify
	r, _, err := (&dns.Client{Net: "udp", Timeout: 2 * time.Second}).Exchange(m, f.Addr())
	if err != nil || r.Rcode != dns.RcodeNotImplemented {
		t.Errorf("NOTIFY: %v, rcode %v", err, r)
	}
}

func TestCacheTTLRules(t *testing.T) {
	msg := func(rcode int, ttl uint32, answers int) *dns.Msg {
		m := new(dns.Msg)
		m.SetQuestion("example.org.", dns.TypeA)
		m.Response, m.Rcode = true, rcode
		for range answers {
			m.Answer = append(m.Answer, &dns.A{Hdr: dns.RR_Header{Name: "example.org.", Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: ttl}, A: net.ParseIP("192.0.2.1")})
		}
		return m
	}
	if d := ttlOf(msg(dns.RcodeSuccess, 120, 1)); d != 120*time.Second {
		t.Errorf("ttl 120 -> %v", d)
	}
	if d := ttlOf(msg(dns.RcodeSuccess, 86400, 1)); d != cacheMaxTTL {
		t.Errorf("a day -> %v, want the %v cap", d, cacheMaxTTL)
	}
	if d := ttlOf(msg(dns.RcodeSuccess, 0, 1)); d != 0 {
		t.Errorf("ttl 0 -> %v, want not cached", d)
	}
	if d := ttlOf(msg(dns.RcodeServerFailure, 60, 0)); d != 0 {
		t.Errorf("SERVFAIL -> %v, want not cached", d)
	}
	if d := ttlOf(msg(dns.RcodeNameError, 0, 0)); d <= 0 || d > cacheNegTTL {
		t.Errorf("NXDOMAIN without SOA -> %v", d)
	}
	tr := msg(dns.RcodeSuccess, 60, 1)
	tr.Truncated = true
	if d := ttlOf(tr); d != 0 {
		t.Errorf("truncated -> %v, want not cached", d)
	}

	c := newAnswerCache(2)
	for _, n := range []string{"a.", "b.", "c."} {
		c.put(n, msg(dns.RcodeSuccess, 60, 1))
	}
	if c.get("a.", 1) != nil {
		t.Error("the oldest entry stayed although the cache holds 2")
	}
	r := c.get("c.", 777)
	if r == nil || r.Id != 777 {
		t.Fatalf("cached answer: %v", r)
	}
	c.mu.Lock()
	c.items["c."].Value.(*cacheEntry).stored = time.Now().Add(-30 * time.Second)
	c.mu.Unlock()
	if r = c.get("c.", 1); r == nil || r.Answer[0].Header().Ttl > 31 || r.Answer[0].Header().Ttl < 29 {
		t.Errorf("TTL after 30 s = %v, want about 30", r)
	}
	c.mu.Lock()
	c.items["c."].Value.(*cacheEntry).expires = time.Now().Add(-time.Second)
	c.mu.Unlock()
	if c.get("c.", 1) != nil {
		t.Error("an expired entry was served")
	}
}

// Some outbounds (Tor, plain HTTP proxies) carry no UDP: the forwarder switches to TCP and stops trying UDP.
func TestFallsBackToTCPWhenTheTunnelCarriesNoUDP(t *testing.T) {
	res := newTestResolver(t, dc.XChacha20Poly1305)
	var udpTries atomic.Int64
	dial := func(ctx context.Context, network, address string) (net.Conn, error) {
		if network == "udp" {
			udpTries.Add(1)
			return nil, errors.New("UDP is not supported by this outbound")
		}
		var d net.Dialer
		return d.DialContext(ctx, network, address)
	}
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp, Dial: dial, CacheEntries: -1})
	for _, name := range []string{"a.example.org", "b.example.org", "c.example.org"} {
		if got := firstA(t, query(t, "udp", f.Addr(), name, dns.TypeA)); got != "192.0.2.1" {
			t.Errorf("answer = %s", got)
		}
	}
	if n := udpTries.Load(); n != 1 {
		t.Errorf("UDP was tried %d times, want once", n)
	}
}

// rotate replaces the resolver's certificate: same ports, same provider key, a new short-term key.
func (r *testResolver) rotate(t *testing.T) {
	t.Helper()
	r.tcp.Close()
	r.udp.Close()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	r.server.Shutdown(ctx)
	cancel()
	rc := r.cfg
	rc.ResolverSk, rc.ResolverPk = "", ""
	cert, err := rc.CreateCert()
	if err != nil {
		t.Fatal(err)
	}
	l, err := net.Listen("tcp", r.addr)
	if err != nil {
		t.Fatal(err)
	}
	_, port, _ := net.SplitHostPort(r.addr)
	p, _ := strconv.Atoi(port)
	pc, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: p})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close(); pc.Close() })
	r.tcp, r.udp = l, pc
	r.server = &dc.Server{ProviderName: rc.ProviderName, ResolverCert: cert, Handler: resolverHandler{r}}
	go r.server.ServeTCP(l)
	go r.server.ServeUDP(pc)
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		r.server.Shutdown(ctx)
	})
}

// The resolver replaces its certificate: a client that cached the old one
// notices that its queries go unanswered and takes the new one.
func TestRecoversWhenTheResolverRotatesItsCertificate(t *testing.T) {
	old := certRetryAfter
	certRetryAfter = 0
	t.Cleanup(func() { certRetryAfter = old })

	res := newTestResolver(t, dc.XChacha20Poly1305)
	f := startForwarder(t, ForwarderConfig{Stamp: res.stamp, CacheEntries: -1, Timeout: 700 * time.Millisecond})
	if got := firstA(t, query(t, "udp", f.Addr(), "before.example.org", dns.TypeA)); got != "192.0.2.1" {
		t.Fatalf("before: %s", got)
	}
	res.rotate(t)
	got := ""
	for range 5 {
		m := new(dns.Msg)
		m.SetQuestion("after.example.org.", dns.TypeA)
		r, _, err := (&dns.Client{Net: "udp", Timeout: 10 * time.Second}).Exchange(m, f.Addr())
		if err == nil && r.Rcode == dns.RcodeSuccess && len(r.Answer) == 1 {
			got = r.Answer[0].(*dns.A).A.String()
			break
		}
	}
	if got != "192.0.2.1" {
		t.Fatalf("the client never took the new certificate (answer %q)", got)
	}
}
