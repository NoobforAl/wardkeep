package dnstt

import (
	"context"
	"io"
	"net"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
	"github.com/NoobforAl/omnitun/third_party/dnstt/server"
)

const zone = "t.example.com"

func startEcho(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				defer c.Close()
				io.Copy(c, c)
			}()
		}
	}()
	return ln.Addr().String()
}

// startServer runs a tunnel server and returns the udp:// address clients can use as their resolver, and its key.
func startServer(t *testing.T, upstream string) (resolver string, keyHex string) {
	t.Helper()
	priv, err := noise.GeneratePrivkey()
	if err != nil {
		t.Fatal(err)
	}
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		server.Serve(ctx, pc, server.Config{Domain: zone, PrivKey: priv, Upstream: upstream})
	}()
	t.Cleanup(func() {
		cancel()
		<-done
	})
	return "udp://" + pc.LocalAddr().String(), noise.EncodeKey(noise.PubkeyFromPrivkey(priv))
}

func echoThrough(t *testing.T, addr string, msg string) {
	t.Helper()
	c, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(20 * time.Second))
	if _, err := c.Write([]byte(msg)); err != nil {
		t.Fatal(err)
	}
	got := make([]byte, len(msg))
	if _, err := io.ReadFull(c, got); err != nil {
		t.Fatalf("reading the echo: %v", err)
	}
	if string(got) != msg {
		t.Fatalf("echo = %q, want %q", got, msg)
	}
}

func TestConfigValidation(t *testing.T) {
	good := Config{Domain: zone, PubKey: "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff", Resolvers: []string{"udp://1.1.1.1:53"}}
	if err := good.Validate(); err != nil {
		t.Fatalf("a good config: %v", err)
	}
	for name, mutate := range map[string]func(*Config){
		"no domain":        func(c *Config) { c.Domain = "" },
		"bad domain":       func(c *Config) { c.Domain = "not a domain!" },
		"short key":        func(c *Config) { c.PubKey = "0011" },
		"key not hex":      func(c *Config) { c.PubKey = "zz" + c.PubKey[2:] },
		"no resolver":      func(c *Config) { c.Resolvers = nil },
		"hostname for UDP": func(c *Config) { c.Resolvers = []string{"udp://dns.google:53"} },
		"plain http":       func(c *Config) { c.Resolvers = []string{"http://dns.google/dns-query"} },
	} {
		c := good
		mutate(&c)
		if err := c.Validate(); err == nil {
			t.Errorf("%s: should be refused", name)
		}
	}
}

func TestTunnelCarriesConnections(t *testing.T) {
	resolver, key := startServer(t, startEcho(t))
	p, err := Start(t.Context(), Config{Domain: zone, PubKey: key, Resolvers: []string{resolver}}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer p.Stop()

	ctx, cancel := context.WithTimeout(t.Context(), 20*time.Second)
	defer cancel()
	if err := p.Ready(ctx); err != nil {
		t.Fatal(err)
	}
	if p.Active() != resolver {
		t.Fatalf("active = %q, want %q", p.Active(), resolver)
	}
	// Several connections at once, each its own stream.
	done := make(chan struct{}, 4)
	for _, msg := range []string{"one", "two two", "three three three", "four four four four"} {
		go func() {
			echoThrough(t, p.Addr, msg)
			done <- struct{}{}
		}()
	}
	for range 4 {
		select {
		case <-done:
		case <-time.After(25 * time.Second):
			t.Fatal("a connection did not finish")
		}
	}

	p.Stop()
	select {
	case <-p.Done():
	default:
		t.Fatal("Done should be closed after Stop")
	}
	if _, err := net.DialTimeout("tcp", p.Addr, time.Second); err == nil {
		t.Error("the local port should be closed after Stop")
	}
}

// The first resolver is dead; the tunnel moves on to the next.
func TestTunnelMovesToTheNextResolver(t *testing.T) {
	resolver, key := startServer(t, startEcho(t))
	p, err := Start(t.Context(), Config{Domain: zone, PubKey: key, Resolvers: []string{"udp://127.0.0.1:9", resolver}}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer p.Stop()
	ctx, cancel := context.WithTimeout(t.Context(), 60*time.Second)
	defer cancel()
	if err := p.Ready(ctx); err != nil {
		t.Fatalf("ready: %v (last error: %v)", err, p.Err())
	}
	if p.Active() != resolver {
		t.Fatalf("active = %q, want the second resolver", p.Active())
	}
	echoThrough(t, p.Addr, "after a failover")
}

// A deferred tunnel has its port at once but opens no socket until it is bound; the sockets then come from the
// functions it was given.
func TestDeferredTunnelWaitsForBind(t *testing.T) {
	resolver, key := startServer(t, startEcho(t))
	var listens atomic.Int32
	p, err := Start(t.Context(), Config{Domain: zone, PubKey: key, Resolvers: []string{resolver}}, Options{Deferred: true})
	if err != nil {
		t.Fatal(err)
	}
	defer p.Stop()

	short, cancel := context.WithTimeout(t.Context(), 1500*time.Millisecond)
	defer cancel()
	if err := p.Ready(short); err == nil {
		t.Fatal("a deferred tunnel must not connect before it is bound")
	}
	if listens.Load() != 0 {
		t.Fatal("no socket should have been opened")
	}

	var remote atomic.Value
	p.Bind(nil, func(ctx context.Context, network, remoteAddr string) (net.PacketConn, error) {
		listens.Add(1)
		remote.Store(remoteAddr)
		return net.ListenPacket(network, "")
	})
	ctx, cancel2 := context.WithTimeout(t.Context(), 20*time.Second)
	defer cancel2()
	if err := p.Ready(ctx); err != nil {
		t.Fatalf("after Bind: %v (last error: %v)", err, p.Err())
	}
	if listens.Load() == 0 {
		t.Fatal("the bound ListenPacket was not used")
	}
	if got, _ := remote.Load().(string); got != strings.TrimPrefix(resolver, "udp://") {
		t.Fatalf("ListenPacket was told the remote %q, want %q", got, strings.TrimPrefix(resolver, "udp://"))
	}
	echoThrough(t, p.Addr, "bound")
}

func TestScanFindsTheWorkingResolvers(t *testing.T) {
	resolver, key := startServer(t, startEcho(t))
	ctx, cancel := context.WithTimeout(t.Context(), 30*time.Second)
	defer cancel()
	res, err := Scan(ctx, Config{Domain: zone, PubKey: key}, []string{"udp://127.0.0.1:9", resolver, "udp://dns.example:53", "garbage"}, Options{}, 4, 3*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if len(res) != 4 {
		t.Fatalf("got %d results", len(res))
	}
	if res[0].Resolver != resolver || res[0].Ms <= 0 || res[0].Err != "" {
		t.Fatalf("the working resolver should come first: %+v", res)
	}
	for _, r := range res[1:] {
		if r.Ms != 0 || r.Err == "" {
			t.Errorf("%s should have failed: %+v", r.Resolver, r)
		}
	}

	if _, err := Scan(ctx, Config{Domain: zone, PubKey: "nonsense"}, nil, Options{}, 1, time.Second); err == nil {
		t.Error("a bad key should be refused before anything is tried")
	}
	if _, err := Scan(ctx, Config{Domain: "", PubKey: key}, nil, Options{}, 1, time.Second); err == nil {
		t.Error("no domain should be refused")
	}
}

// A resolver that takes the connection and then says nothing, as a middlebox can on a mobile network, must
// not hold a scan past its time: found on a phone, where a scan never ended.
func TestScanEndsWhenAResolverAcceptsAndStaysSilent(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			defer c.Close() // never answers
		}
	}()
	key := strings.Repeat("ab", 32)
	for _, r := range []string{"tls://" + ln.Addr().String()} {
		start := time.Now()
		ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
		res, _ := Scan(ctx, Config{Domain: zone, PubKey: key}, []string{r}, Options{}, 1, time.Second)
		cancel()
		if d := time.Since(start); d > 3*time.Second {
			t.Fatalf("the scan of %s took %v: a silent resolver held it", r, d)
		}
		if len(res) != 1 || res[0].Ms != 0 || res[0].Err == "" {
			t.Fatalf("a silent resolver should fail, got %+v", res)
		}
	}
}
