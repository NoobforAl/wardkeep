package hostproto

import (
	"context"
	"encoding/hex"
	"net"
	"net/netip"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/miekg/dns"

	"github.com/NoobforAl/omnitun/core/dnscrypt"
	"github.com/NoobforAl/omnitun/core/protocols"
	"github.com/NoobforAl/omnitun/server/store"
)

// fakeUpstream answers every A query with 192.0.2.77 over UDP and TCP and counts them.
func fakeUpstream(t *testing.T) (addr string, queries *atomic.Int64) {
	t.Helper()
	queries = new(atomic.Int64)
	h := dns.HandlerFunc(func(w dns.ResponseWriter, r *dns.Msg) {
		queries.Add(1)
		m := new(dns.Msg)
		m.SetReply(r)
		m.Answer = append(m.Answer, &dns.A{Hdr: dns.RR_Header{Name: r.Question[0].Name, Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: 60}, A: net.ParseIP("192.0.2.77")})
		w.WriteMsg(m)
	})
	for range 50 {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		pc, err := net.ListenPacket("udp", l.Addr().String())
		if err != nil {
			l.Close()
			continue
		}
		udp := &dns.Server{PacketConn: pc, Handler: h}
		tcp := &dns.Server{Listener: l, Handler: h}
		started := make(chan struct{}, 2)
		udp.NotifyStartedFunc = func() { started <- struct{}{} }
		tcp.NotifyStartedFunc = func() { started <- struct{}{} }
		go udp.ActivateAndServe()
		go tcp.ActivateAndServe()
		<-started
		<-started
		t.Cleanup(func() { udp.Shutdown(); tcp.Shutdown() })
		return l.Addr().String(), queries
	}
	t.Fatal("no port for the fake upstream")
	return "", nil
}

func freePort(t *testing.T) int {
	t.Helper()
	for range 50 {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		port := l.Addr().(*net.TCPAddr).Port
		pc, err := net.ListenPacket("udp", "127.0.0.1:"+strconv.Itoa(port))
		l.Close()
		if err == nil {
			pc.Close()
			return port
		}
	}
	t.Fatal("no free port")
	return 0
}

type logCollector struct {
	mu    sync.Mutex
	lines []string
}

func (l *logCollector) logf(format string, args ...any) {
	l.mu.Lock()
	l.lines = append(l.lines, format)
	l.mu.Unlock()
}

func (l *logCollector) count(substr string) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	n := 0
	for _, s := range l.lines {
		if strings.Contains(s, substr) {
			n++
		}
	}
	return n
}

type dnsCryptHarness struct {
	srv      Server
	port     int
	stamp    dnscrypt.Stamp
	upstream *atomic.Int64
	logs     *logCollector
}

func startDNSCryptHarness(t *testing.T, rotate time.Duration) *dnsCryptHarness {
	t.Helper()
	upAddr, upQueries := fakeUpstream(t)
	id, err := store.NewDNSCrypt("Test Server")
	if err != nil {
		t.Fatal(err)
	}
	id.Upstream = upAddr
	port := freePort(t)
	logs := &logCollector{}
	srv, err := Start("dnscrypt", Config{
		Env: protocols.Env{DNSCrypt: protocols.DNSCrypt{
			ProviderName: id.ProviderName, PublicKey: id.PublicKey, PrivateKey: id.PrivateKey, Upstream: id.Upstream, Listen: "127.0.0.1",
		}},
		Port: port, DNSRotateEvery: rotate, Logf: logs.logf,
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { srv.Close() })
	pub, _ := hex.DecodeString(id.PublicKey)
	return &dnsCryptHarness{
		srv: srv, port: port, upstream: upQueries, logs: logs,
		stamp: dnscrypt.Stamp{Kind: dnscrypt.KindDNSCrypt, Addr: "127.0.0.1:" + strconv.Itoa(port), PublicKey: pub, ProviderName: id.ProviderName},
	}
}

func askThrough(t *testing.T, stamp string, name string) *dns.Msg {
	t.Helper()
	f, err := dnscrypt.NewForwarder(dnscrypt.ForwarderConfig{Stamp: stamp, Timeout: 2 * time.Second, CacheEntries: -1})
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Start(); err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), dns.TypeA)
	r, _, err := (&dns.Client{Net: "udp", Timeout: 8 * time.Second}).Exchange(m, f.Addr())
	if err != nil {
		t.Fatal(err)
	}
	return r
}

// The server's resolver speaks real DNSCrypt: the client side of core/dnscrypt,
// given the server's stamp, gets the upstream's answer through it.
func TestDNSCryptResolverAnswersAClient(t *testing.T) {
	h := startDNSCryptHarness(t, 0)
	if h.srv.Pool() != "" {
		t.Errorf("the resolver has a tunnel network: %q", h.srv.Pool())
	}
	r := askThrough(t, h.stamp.String(), "resolver-test.example.org")
	if r.Rcode != dns.RcodeSuccess || len(r.Answer) != 1 || r.Answer[0].(*dns.A).A.String() != "192.0.2.77" {
		t.Fatalf("answer: rcode %s, %v", dns.RcodeToString[r.Rcode], r.Answer)
	}
	if h.upstream.Load() != 1 {
		t.Errorf("the upstream saw %d queries, want 1", h.upstream.Load())
	}
}

// A client holding another key in its stamp does not trust the resolver: the
// certificate fails its signature check.
func TestDNSCryptResolverIsRejectedWithAnotherKey(t *testing.T) {
	h := startDNSCryptHarness(t, 0)
	other, err := store.NewDNSCrypt("other")
	if err != nil {
		t.Fatal(err)
	}
	h.stamp.PublicKey, _ = hex.DecodeString(other.PublicKey)
	f, err := dnscrypt.NewForwarder(dnscrypt.ForwarderConfig{Stamp: h.stamp.String(), Timeout: 2 * time.Second})
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := f.Check(context.Background()); err == nil {
		t.Fatal("a resolver with another key was accepted")
	}
}

// The short-term key and certificate are replaced on schedule, the resolver
// keeps serving on the same port, and a client that takes the certificate
// afterwards trusts it (the provider key is the same). A client that cached the
// old certificate recovers: see core/dnscrypt.
func TestDNSCryptResolverRotatesItsCertificate(t *testing.T) {
	h := startDNSCryptHarness(t, 400*time.Millisecond)
	if r := askThrough(t, h.stamp.String(), "first.example.org"); len(r.Answer) != 1 {
		t.Fatalf("no answer before the rotation: %v", r)
	}
	first := h.srv.(*dnsCryptServer)
	first.mu.Lock()
	serial0 := first.serial
	first.mu.Unlock()
	deadline := time.Now().Add(15 * time.Second)
	for h.logs.count("new short-term key") < 2 && time.Now().Before(deadline) {
		time.Sleep(50 * time.Millisecond)
	}
	if h.logs.count("new short-term key") < 2 {
		t.Fatal("the certificate was not rotated twice in 15 s")
	}
	s := h.srv.(*dnsCryptServer)
	s.mu.Lock()
	serial := s.serial
	s.mu.Unlock()
	if serial <= serial0 {
		t.Errorf("certificate serial %d after two rotations, was %d; it must count up", serial, serial0)
	}
	var ok bool
	for range 10 { // a query may land in the moment between two certificates
		r := askThrough(t, h.stamp.String(), "after.example.org")
		if ok = r.Rcode == dns.RcodeSuccess && len(r.Answer) == 1; ok {
			break
		}
	}
	if !ok {
		t.Fatal("no answer after the rotations")
	}
}

func TestDNSCryptResolverFreesItsPort(t *testing.T) {
	h := startDNSCryptHarness(t, 0)
	if err := h.srv.Close(); err != nil {
		t.Fatal(err)
	}
	l, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(h.port))
	if err != nil {
		t.Fatalf("the TCP port is still taken: %v", err)
	}
	l.Close()
	pc, err := net.ListenPacket("udp", "127.0.0.1:"+strconv.Itoa(h.port))
	if err != nil {
		t.Fatalf("the UDP port is still taken: %v", err)
	}
	pc.Close()
}

func TestDNSCryptResolverNeedsItsKey(t *testing.T) {
	if _, err := Start("dnscrypt", Config{Port: freePort(t), Env: protocols.Env{DNSCrypt: protocols.DNSCrypt{Listen: "127.0.0.1"}}}); err == nil {
		t.Fatal("started without a key")
	}
}

func TestRateLimiterLimitsOneAddressNotAnother(t *testing.T) {
	l := newRateLimiter(10, 5)
	a, b := netip.MustParseAddr("192.0.2.1"), netip.MustParseAddr("192.0.2.2")
	allowed := 0
	for range 20 {
		if l.allow(a) {
			allowed++
		}
	}
	if allowed < 5 || allowed > 6 {
		t.Errorf("a burst of 20 let %d through, want about 5", allowed)
	}
	if !l.allow(b) {
		t.Error("another address was limited too")
	}
	time.Sleep(250 * time.Millisecond) // 2.5 tokens
	if !l.allow(a) {
		t.Error("the bucket did not refill")
	}
}

// There is no default listen address and the wildcard is refused: the resolver
// cannot come up open on the public interface.
func TestDNSCryptResolverNeverListensOnEveryInterface(t *testing.T) {
	for _, listen := range []string{"", "0.0.0.0", "::", "224.0.0.1", "not-an-ip"} {
		id, _ := store.NewDNSCrypt("x")
		_, err := Start("dnscrypt", Config{
			Port: freePort(t),
			Env:  protocols.Env{DNSCrypt: protocols.DNSCrypt{ProviderName: id.ProviderName, PublicKey: id.PublicKey, PrivateKey: id.PrivateKey, Listen: listen}},
		})
		if err == nil {
			t.Errorf("listen %q: the resolver started", listen)
		} else if listen == "" && !strings.Contains(err.Error(), "dnscrypt listen") {
			t.Errorf("the error does not say how to set the address: %v", err)
		}
	}
	// A range that is every address is refused too.
	id, _ := store.NewDNSCrypt("x")
	_, err := Start("dnscrypt", Config{
		Port: freePort(t),
		Env: protocols.Env{DNSCrypt: protocols.DNSCrypt{ProviderName: id.ProviderName, PublicKey: id.PublicKey, PrivateKey: id.PrivateKey,
			Listen: "127.0.0.1", Allow: []string{"0.0.0.0/0"}}},
	})
	if err == nil {
		t.Error("an allow range of every address was accepted")
	}
}

// The host's /etc/resolv.conf is not the default upstream.
func TestDNSCryptDefaultUpstreamIsPublicNotTheHosts(t *testing.T) {
	if got := upstreamResolver(""); got != "1.1.1.1:53" {
		t.Errorf("default upstream = %q, want 1.1.1.1:53", got)
	}
	if got := upstreamResolver("9.9.9.9"); got != "9.9.9.9:53" {
		t.Errorf("upstream 9.9.9.9 = %q", got)
	}
	if got := upstreamResolver("9.9.9.9:5353"); got != "9.9.9.9:5353" {
		t.Errorf("upstream with port = %q", got)
	}
	// "system" is the only way to the host's resolver; without a resolv.conf it still ends at the public one.
	if got := upstreamResolver(protocols.UpstreamSystem); got == "" {
		t.Error("system upstream is empty")
	}
}

func TestGateAllowsClientsAndDropsTheRest(t *testing.T) {
	g := newGate(mustPrefixes("203.0.113.0/24"))
	for _, ok := range []string{"127.0.0.1", "::1", "10.30.4.5", "10.31.0.9", "10.18.0.2", "fd30:0:0:1::5", "::ffff:10.30.0.2", "203.0.113.9"} {
		if !g.permitted(netip.MustParseAddr(ok)) {
			t.Errorf("%s was refused", ok)
		}
	}
	for _, no := range []string{"8.8.8.8", "198.51.100.7", "10.32.0.1", "2606:4700::1111", "192.168.1.5", "203.0.114.1", "10.9.0.3", "10.10.10.7"} {
		if g.permitted(netip.MustParseAddr(no)) {
			t.Errorf("%s was allowed", no)
		}
	}
}

// Queries from a source that is not a client get no answer at all, over UDP,
// TCP and for the certificate request alike; with the source allowed again the
// same questions are answered.
func TestDNSCryptResolverDropsSourcesThatAreNotClients(t *testing.T) {
	h := startDNSCryptHarness(t, 0)
	s := h.srv.(*dnsCryptServer)
	setStatic := func(p []netip.Prefix) {
		s.gate.mu.Lock()
		s.gate.static = p
		s.gate.own, s.gate.ownAt = nil, time.Now() // no "own addresses" either
		s.gate.mu.Unlock()
	}
	setStatic(nil) // even loopback is now a stranger
	addr := "127.0.0.1:" + strconv.Itoa(h.port)

	// The certificate request, plain DNS over UDP and over TCP.
	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(h.stamp.ProviderName), dns.TypeTXT)
	for _, network := range []string{"udp", "tcp"} {
		c := &dns.Client{Net: network, Timeout: 700 * time.Millisecond}
		if r, _, err := c.Exchange(m, addr); err == nil {
			t.Errorf("%s: a stranger got the certificate: %v", network, r.Answer)
		}
	}
	f, err := dnscrypt.NewForwarder(dnscrypt.ForwarderConfig{Stamp: h.stamp.String(), Timeout: 700 * time.Millisecond})
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := f.Check(context.Background()); err == nil {
		t.Error("a stranger fetched the certificate through the client")
	}
	if h.upstream.Load() != 0 {
		t.Errorf("the upstream was asked %d times for a stranger", h.upstream.Load())
	}

	setStatic(mustPrefixes("127.0.0.0/8"))
	f2 := askThrough(t, h.stamp.String(), "now-a-client.example.org")
	if len(f2.Answer) != 1 {
		t.Fatalf("a client was not answered: %v", f2)
	}
}

// Certificate requests are limited much harder than queries.
func TestDNSCryptResolverLimitsCertificateRequests(t *testing.T) {
	h := startDNSCryptHarness(t, 0)
	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(h.stamp.ProviderName), dns.TypeTXT)
	raw, _ := m.Pack()
	c, err := net.Dial("udp", "127.0.0.1:"+strconv.Itoa(h.port))
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	for range 40 {
		c.Write(raw)
	}
	answers := 0
	buf := make([]byte, 4096)
	for {
		c.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
		if _, err := c.Read(buf); err != nil {
			break
		}
		answers++
	}
	if answers == 0 || answers > dnsCertBurst+2 {
		t.Errorf("%d answers to 40 certificate requests, want between 1 and about %d", answers, dnsCertBurst)
	}
}

func TestDNSCryptResolverRefusesANY(t *testing.T) {
	h := startDNSCryptHarness(t, 0)
	f, err := dnscrypt.NewForwarder(dnscrypt.ForwarderConfig{Stamp: h.stamp.String(), Timeout: 2 * time.Second, CacheEntries: -1})
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Start(); err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	m := new(dns.Msg)
	m.SetQuestion("any.example.org.", dns.TypeANY)
	r, _, err := (&dns.Client{Net: "udp", Timeout: 5 * time.Second}).Exchange(m, f.Addr())
	if err != nil || r.Rcode != dns.RcodeNotImplemented || len(r.Answer) != 0 {
		t.Errorf("ANY: %v %v", err, r)
	}
	if h.upstream.Load() != 0 {
		t.Error("the upstream was asked for ANY")
	}
}

// When the session table is full, idle sessions are evicted; their reply
// goroutines must end (not spin on read errors from the closed socket), so the
// table's limit really bounds the resources.
func TestUDPFrontEvictionEndsTheReplyGoroutines(t *testing.T) {
	// A UDP socket standing in for the DNSCrypt server behind the front.
	inner, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	defer inner.Close()
	outer, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	f := &udpFront{
		conn: outer, target: inner.LocalAddr().(*net.UDPAddr), inner: inner, gate: newGate(nil),
		sessions: map[netip.AddrPort]*udpSession{}, done: make(chan struct{}),
		maxSessions: 4, idle: 10 * time.Second,
	}
	f.gate.query = newRateLimiter(1000, 1000)
	f.gate.cert = newRateLimiter(1000, 1000)
	go f.run()
	defer f.close()

	settle := func(want int) int {
		n := runtime.NumGoroutine()
		for range 60 {
			if n = runtime.NumGoroutine(); n <= want {
				break
			}
			time.Sleep(50 * time.Millisecond)
		}
		return n
	}
	send := func(c *net.UDPConn) { c.WriteToUDP(make([]byte, 40), outer.LocalAddr().(*net.UDPAddr)) }
	newClient := func() *net.UDPConn {
		c, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { c.Close() })
		return c
	}
	sessions := func() int { f.mu.Lock(); defer f.mu.Unlock(); return len(f.sessions) }
	waitFor := func(what string, ok func() bool) {
		for range 100 {
			if ok() {
				return
			}
			time.Sleep(20 * time.Millisecond)
		}
		t.Fatalf("timed out: %s", what)
	}

	base := runtime.NumGoroutine()
	age := func() { // make every session look idle for a long time (their own read timeouts are far off)
		f.mu.Lock()
		for _, sess := range f.sessions {
			sess.last = time.Now().Add(-time.Hour)
		}
		f.mu.Unlock()
	}
	for range 4 { // the table is full
		send(newClient())
	}
	waitFor("four sessions", func() bool { return sessions() == 4 })

	// Each new client finds a full table of idle sessions and evicts them.
	for range 12 {
		age()
		send(newClient())
		time.Sleep(20 * time.Millisecond)
	}
	if n := sessions(); n < 1 || n > 4 {
		t.Fatalf("%d sessions in a table of 4", n)
	}

	// The evicted sessions' goroutines are gone: only the live sessions' remain, and nobody spins.
	live := sessions()
	if n := settle(base + live); n > base+live {
		t.Errorf("%d goroutines with %d live sessions, %d before: evicted sessions leave goroutines behind", n, live, base)
	}
	before := f.reads.Load()
	time.Sleep(300 * time.Millisecond)
	if spun := f.reads.Load() - before; spun > 5 {
		t.Errorf("%d reads in 300 ms with no traffic: the reply goroutines are spinning", spun)
	}

	// Closing the front ends the rest.
	f.close()
	if n := settle(base); n > base {
		t.Errorf("%d goroutines after closing the front, %d before", n, base)
	}
}
