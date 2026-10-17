package hostproto

import (
	"context"
	"encoding/hex"
	"net"
	"net/netip"
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
		Env:  protocols.Env{DNSCrypt: protocols.DNSCrypt{ProviderName: id.ProviderName, PublicKey: id.PublicKey, PrivateKey: id.PrivateKey, Upstream: id.Upstream}},
		Port: port, DNSListen: "127.0.0.1", DNSRotateEvery: rotate, Logf: logs.logf,
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
	if _, err := Start("dnscrypt", Config{Port: freePort(t), DNSListen: "127.0.0.1"}); err == nil {
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
