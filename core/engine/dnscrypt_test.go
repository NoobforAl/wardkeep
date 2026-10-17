//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"slices"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	dc "github.com/ameshkov/dnscrypt/v2"
	"github.com/miekg/dns"
	M "github.com/sagernet/sing/common/metadata"

	"github.com/NoobforAl/omnitun/core/dnscrypt"
	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// dnsCryptResolver runs the library's DNSCrypt server on loopback; it answers
// every A query with 192.0.2.1.
type dnsCryptResolver struct {
	addr    string
	stamp   string
	queries atomic.Int64
}

type canned struct{ r *dnsCryptResolver }

func (h canned) ServeDNS(rw dc.ResponseWriter, q *dns.Msg) error {
	h.r.queries.Add(1)
	m := new(dns.Msg)
	m.SetReply(q)
	m.Answer = append(m.Answer, &dns.A{Hdr: dns.RR_Header{Name: q.Question[0].Name, Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: 60}, A: net.ParseIP("192.0.2.1")})
	return rw.WriteMsg(m)
}

func startDNSCryptResolver(t *testing.T) *dnsCryptResolver {
	t.Helper()
	r := &dnsCryptResolver{}
	cfg, err := dc.GenerateResolverConfig("engine.test", nil)
	if err != nil {
		t.Fatal(err)
	}
	cfg.EsVersion = dc.XChacha20Poly1305
	cert, err := cfg.CreateCert()
	if err != nil {
		t.Fatal(err)
	}
	var l net.Listener
	var pc *net.UDPConn
	for range 50 {
		l, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		pc, err = net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: l.Addr().(*net.TCPAddr).Port})
		if err == nil {
			break
		}
		l.Close()
	}
	if err != nil {
		t.Fatal(err)
	}
	r.addr = l.Addr().String()
	server := &dc.Server{ProviderName: cfg.ProviderName, ResolverCert: cert, Handler: canned{r}}
	go server.ServeTCP(l)
	go server.ServeUDP(pc)
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		server.Shutdown(ctx)
	})
	st, err := cfg.CreateStamp(r.addr)
	if err != nil {
		t.Fatal(err)
	}
	r.stamp = st.String()
	return r
}

func ask(t *testing.T, addr, name string) *dns.Msg {
	t.Helper()
	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), dns.TypeA)
	r, _, err := (&dns.Client{Net: "udp", Timeout: 5 * time.Second}).Exchange(m, addr)
	if err != nil {
		t.Fatalf("query %s: %v", name, err)
	}
	return r
}

// A stand-in for the tunnel's outbound that records where the forwarder dials.
type recordingOutbound struct {
	mu      sync.Mutex
	targets []string
}

func (o *recordingOutbound) DialContext(ctx context.Context, network string, dest M.Socksaddr) (net.Conn, error) {
	o.mu.Lock()
	o.targets = append(o.targets, network+" "+dest.String())
	o.mu.Unlock()
	var d net.Dialer
	return d.DialContext(ctx, network, dest.String())
}

// Until the tunnel is up the forwarder has no way out: queries fail, they do
// not go around the VPN. Afterwards every socket is opened by the tunnel's outbound.
func TestDNSCryptForwarderOnlyUsesTheTunnelOutbound(t *testing.T) {
	res := startDNSCryptResolver(t)
	e := New(Config{DataDir: tempDir(t)})
	opts := singbox.Options{DNS: res.stamp}
	if err := e.startDNSCryptLocked(&opts); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { e.stopDNSCryptLocked() })
	if opts.DNSForwarder == "" || e.dnsRun == nil {
		t.Fatalf("no forwarder: %+v", opts)
	}

	if r := ask(t, opts.DNSForwarder, "before.example.org"); r.Rcode != dns.RcodeServerFailure {
		t.Errorf("before the tunnel is up the rcode was %s, want SERVFAIL", dns.RcodeToString[r.Rcode])
	}
	if res.queries.Load() != 0 {
		t.Fatal("the resolver was reached without the tunnel")
	}

	out := &recordingOutbound{}
	e.dnsRun.setOutbound(out)
	e.dnsRun.fwd.Retry()
	if r := ask(t, opts.DNSForwarder, "after.example.org"); r.Rcode != dns.RcodeSuccess || len(r.Answer) != 1 {
		t.Fatalf("after: rcode %s, %d answers", dns.RcodeToString[r.Rcode], len(r.Answer))
	}
	out.mu.Lock()
	targets := slices.Clone(out.targets)
	out.mu.Unlock()
	if len(targets) == 0 {
		t.Fatal("the outbound was never used")
	}
	for _, tg := range targets {
		if tg != "udp "+res.addr {
			t.Errorf("dialed %q; want only udp to the resolver %s", tg, res.addr)
		}
	}

	resolver, anon, stats, ok := e.DNSStatus()
	if !ok || resolver != "engine.test" || anon || stats.Answered != 1 {
		t.Errorf("DNSStatus = %q %v %+v %v", resolver, anon, stats, ok)
	}
	e.stopDNSCryptLocked()
	if c, err := net.DialTimeout("tcp", opts.DNSForwarder, time.Second); err == nil {
		c.Close()
		t.Error("the forwarder still listens after stop")
	}
}

func TestOtherResolverSettingsStartNoForwarder(t *testing.T) {
	e := New(Config{DataDir: tempDir(t)})
	for _, dns := range []string{"", "https://1.1.1.1/dns-query", "tls://9.9.9.9", "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"} {
		opts := singbox.Options{DNS: dns}
		if err := e.startDNSCryptLocked(&opts); err != nil || e.dnsRun != nil || opts.DNSForwarder != "" {
			t.Errorf("DNS %q: err %v, forwarder %v", dns, err, opts.DNSForwarder)
		}
	}
	bad := singbox.Options{DNS: "sdns://AQcAAAAAAAAADTkuOS45LjEwOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA", DNSRelay: "not a relay"}
	if err := e.startDNSCryptLocked(&bad); err == nil || e.dnsRun != nil {
		t.Errorf("a bad relay was accepted: %v", err)
	}
}

// What the generated sing-box config looks like for each kind of stamp, and that sing-box accepts it.
func TestSingboxAcceptsDNSStampConfigs(t *testing.T) {
	res, err := importer.Import("ss://aes-128-gcm:test-pass@127.0.0.1:9#local")
	if err != nil {
		t.Fatal(err)
	}
	const (
		quad9   = "sdns://AQcAAAAAAAAADTkuOS45LjEwOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA"
		cfDoH   = "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"
		relayIP = "sdns://gREzNy4xMjAuMjE3Ljc1OjQ0Mw" // 37.120.217.75:443
	)
	dot := dnscrypt.Stamp{Kind: dnscrypt.KindDoT, Addr: "9.9.9.9", Host: "dns.quad9.net"}.String()
	doq := dnscrypt.Stamp{Kind: dnscrypt.KindDoQ, Addr: "94.140.14.14", Host: "dns.adguard-dns.com"}.String()
	plain := dnscrypt.Stamp{Kind: dnscrypt.KindPlain, Addr: "192.0.2.53"}.String()

	type want struct {
		typ, server string
		port        int
		detour      bool
		sni         string
		cidrs       []string
	}
	cases := []struct {
		name string
		opts singbox.Options
		want want
	}{
		{"dnscrypt", singbox.Options{DNS: quad9, DNSForwarder: "127.0.0.1:45353"}, want{"udp", "127.0.0.1", 45353, false, "", []string{"9.9.9.10/32"}}},
		{"dnscrypt anonymized", singbox.Options{DNS: quad9, DNSForwarder: "127.0.0.1:45353", DNSRelay: relayIP}, want{"udp", "127.0.0.1", 45353, false, "", []string{"9.9.9.10/32", "37.120.217.75/32"}}},
		{"dnscrypt relay as ip:port", singbox.Options{DNS: quad9, DNSForwarder: "127.0.0.1:45353", DNSRelay: "203.0.113.5:4443"}, want{"udp", "127.0.0.1", 45353, false, "", []string{"9.9.9.10/32", "203.0.113.5/32"}}},
		{"doh", singbox.Options{DNS: cfDoH}, want{"https", "1.0.0.1", 443, true, "dns.cloudflare.com", []string{"1.0.0.1/32"}}},
		{"dot", singbox.Options{DNS: dot}, want{"tls", "9.9.9.9", 853, true, "dns.quad9.net", []string{"9.9.9.9/32"}}},
		{"doq", singbox.Options{DNS: doq}, want{"quic", "94.140.14.14", 853, true, "dns.adguard-dns.com", []string{"94.140.14.14/32"}}},
		{"plain", singbox.Options{DNS: plain}, want{"udp", "192.0.2.53", 53, true, "", []string{"192.0.2.53/32"}}},
		{"url", singbox.Options{DNS: "tls://1.1.1.1"}, want{"tls", "1.1.1.1", 0, true, "", nil}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			c.opts.Selected = res.Profiles[0].ID
			for _, mode := range []singbox.Mode{singbox.ModeProxy, singbox.ModeTUN} {
				c.opts.Mode = mode
				cfg, _, err := singbox.Build(res.Profiles, c.opts)
				if err != nil {
					t.Fatal(err)
				}
				if err := CheckConfig(cfg); err != nil {
					t.Fatalf("sing-box rejects the config (%s): %v", mode, err)
				}
				servers := cfg["dns"].(map[string]any)["servers"].([]any)
				var remote map[string]any
				for _, s := range servers {
					if m := s.(map[string]any); m["tag"] == "remote" {
						remote = m
					}
				}
				if remote["type"] != c.want.typ || remote["server"] != c.want.server {
					t.Fatalf("remote DNS = %v", remote)
				}
				if p, _ := remote["server_port"].(int); p != c.want.port {
					t.Errorf("server_port = %v, want %d", remote["server_port"], c.want.port)
				}
				if _, has := remote["detour"]; has != c.want.detour {
					t.Errorf("detour present = %v, want %v (%v)", has, c.want.detour, remote)
				}
				if c.want.detour && remote["detour"] != singbox.TagSelect {
					t.Errorf("detour = %v, want the tunnel", remote["detour"])
				}
				if c.want.sni != "" {
					tls, _ := remote["tls"].(map[string]any)
					if tls["server_name"] != c.want.sni {
						t.Errorf("tls = %v, want server_name %s", remote["tls"], c.want.sni)
					}
				}
				// The resolver and relay addresses are routed into the VPN, ahead of every bypass rule.
				var pinned []string
				for _, r := range cfg["route"].(map[string]any)["rules"].([]any) {
					m := r.(map[string]any)
					if m["outbound"] == singbox.TagSelect {
						if cidr, ok := m["ip_cidr"].([]string); ok && len(cidr) > 0 && cidr[0] != "" {
							pinned = cidr
							break
						}
					}
				}
				if !slices.Equal(pinned, c.want.cidrs) {
					t.Errorf("routed through the VPN = %v, want %v", pinned, c.want.cidrs)
				}
			}
		})
	}

	// Things that are not usable as the resolver, or need the engine, say why.
	for name, o := range map[string]singbox.Options{
		"dnscrypt without a forwarder": {DNS: quad9},
		"a relay as the resolver":      {DNS: relayIP},
		"a bad stamp":                  {DNS: "sdns://AAAA"},
		"a bad relay":                  {DNS: quad9, DNSForwarder: "127.0.0.1:1", DNSRelay: "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5"},
	} {
		if _, _, err := singbox.Build(res.Profiles, o); err == nil {
			t.Errorf("%s: Build accepted it", name)
		} else {
			t.Logf("%s: %v", name, err)
		}
	}
}

// socks5Connect opens a SOCKS5 connection through the engine's proxy port to an IPv4 target.
func socks5Connect(t *testing.T, proxyPort int, host string, port int) net.Conn {
	t.Helper()
	c, err := net.DialTimeout("tcp", "127.0.0.1:"+strconv.Itoa(proxyPort), 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	c.SetDeadline(time.Now().Add(10 * time.Second))
	c.Write([]byte{5, 1, 0})
	var rep [2]byte
	if _, err := io.ReadFull(c, rep[:]); err != nil || rep[1] != 0 {
		t.Fatalf("socks greeting: %v %v", rep, err)
	}
	req := append([]byte{5, 1, 0, 1}, net.ParseIP(host).To4()...)
	req = binary.BigEndian.AppendUint16(req, uint16(port))
	c.Write(req)
	var reply [10]byte
	if _, err := io.ReadFull(c, reply[:]); err != nil || reply[1] != 0 {
		t.Fatalf("socks connect: %v %v", reply, err)
	}
	return c
}

// countingRelay passes TCP connections and UDP packets on to target and counts
// them, on the same port number for both.
func countingRelay(t *testing.T, target string) (addr string, count *atomic.Int64) {
	t.Helper()
	var l net.Listener
	var pc *net.UDPConn
	for range 50 {
		var err error
		if l, err = net.Listen("tcp", "127.0.0.1:0"); err != nil {
			t.Fatal(err)
		}
		if pc, err = net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: l.Addr().(*net.TCPAddr).Port}); err == nil {
			break
		}
		l.Close()
	}
	t.Cleanup(func() { l.Close(); pc.Close() })
	count = new(atomic.Int64)
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			count.Add(1)
			go func() {
				up, err := net.Dial("tcp", target)
				if err != nil {
					c.Close()
					return
				}
				go func() { io.Copy(up, c); up.Close() }()
				io.Copy(c, up)
				c.Close()
			}()
		}
	}()
	go func() {
		var mu sync.Mutex
		ups := map[string]*net.UDPConn{}
		buf := make([]byte, 65535)
		for {
			n, from, err := pc.ReadFromUDP(buf)
			if err != nil {
				return
			}
			mu.Lock()
			up := ups[from.String()]
			if up == nil {
				ta, _ := net.ResolveUDPAddr("udp", target)
				if up, err = net.DialUDP("udp", nil, ta); err != nil {
					mu.Unlock()
					continue
				}
				ups[from.String()] = up
				go func() {
					rb := make([]byte, 65535)
					for {
						m, err := up.Read(rb)
						if err != nil {
							return
						}
						pc.WriteToUDP(rb[:m], from)
					}
				}()
			}
			mu.Unlock()
			count.Add(1)
			up.Write(buf[:n])
		}
	}()
	return l.Addr().String(), count
}

// The whole chain with a real sing-box tunnel: a DNS query sent into the proxy
// is hijacked by sing-box, handed to the DNSCrypt forwarder, and reaches the
// DNSCrypt resolver through the Shadowsocks server, not around it.
func TestEndToEndDNSCryptThroughTheTunnel(t *testing.T) {
	resolver := startDNSCryptResolver(t)

	ssPort := freePort(t)
	startServer(t, map[string]any{
		"type": "shadowsocks", "listen": "127.0.0.1", "listen_port": ssPort,
		"method": "aes-128-gcm", "password": "test-pass", "network": []string{"tcp", "udp"},
	})
	// The client talks to the server through a counter, so the test can tell
	// that the forwarder's queries really went through the tunnel.
	relayAddr, conns := countingRelay(t, "127.0.0.1:"+strconv.Itoa(ssPort))
	_, relayPort, _ := net.SplitHostPort(relayAddr)
	res, err := importer.Import(fmt.Sprintf("ss://aes-128-gcm:test-pass@127.0.0.1:%s#local", relayPort))
	if err != nil {
		t.Fatal(err)
	}

	proxyPort := freePort(t)
	e := New(Config{DataDir: tempDir(t), CertificateStore: "mozilla", SkipHandshake: true})
	err = e.Start(res.Profiles, singbox.Options{
		ListenPort: proxyPort,
		LogLevel:   "error",
		Selected:   res.Profiles[0].ID,
		DNS:        resolver.stamp,
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { e.Stop() })
	if name, _, _, ok := e.DNSStatus(); !ok || name != "engine.test" {
		t.Fatalf("DNSStatus = %q %v", name, ok)
	}
	time.Sleep(500 * time.Millisecond) // let anything the start itself sends settle
	before := conns.Load()

	// DNS over TCP to any address on port 53 is hijacked by sing-box's DNS.
	c := socks5Connect(t, proxyPort, "192.0.2.53", 53)
	defer c.Close()
	q := new(dns.Msg)
	q.SetQuestion("through-the-tunnel.example.org.", dns.TypeA)
	packed, _ := q.Pack()
	c.Write(append(binary.BigEndian.AppendUint16(nil, uint16(len(packed))), packed...))
	var l [2]byte
	if _, err := io.ReadFull(c, l[:]); err != nil {
		t.Fatalf("no DNS answer: %v", err)
	}
	buf := make([]byte, binary.BigEndian.Uint16(l[:]))
	if _, err := io.ReadFull(c, buf); err != nil {
		t.Fatal(err)
	}
	var ans dns.Msg
	if err := ans.Unpack(buf); err != nil {
		t.Fatal(err)
	}
	if ans.Rcode != dns.RcodeSuccess || len(ans.Answer) != 1 || ans.Answer[0].(*dns.A).A.String() != "192.0.2.1" {
		t.Fatalf("answer: rcode %s, %v", dns.RcodeToString[ans.Rcode], ans.Answer)
	}
	if resolver.queries.Load() != 1 {
		t.Errorf("the DNSCrypt resolver saw %d queries, want 1", resolver.queries.Load())
	}
	if conns.Load() == before {
		t.Error("no connection went through the Shadowsocks server: the DNSCrypt exchange bypassed the tunnel")
	}
}
