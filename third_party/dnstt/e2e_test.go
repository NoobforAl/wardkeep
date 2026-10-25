package dnstt_test

import (
	"context"
	"io"
	"net"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/third_party/dnstt/client"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
	"github.com/NoobforAl/omnitun/third_party/dnstt/server"
)

const zone = "t.example.com"

// startEcho runs a TCP server that sends back whatever it is sent, and returns its address.
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

// startServer runs a tunnel server on loopback UDP for the zone and returns its "resolver" address (the client
// talks to it directly, which is all a resolver does: pass the queries on) and its public key.
func startServer(t *testing.T, upstream string) (resolver string, pub []byte) {
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
	return "udp://" + pc.LocalAddr().String(), noise.PubkeyFromPrivkey(priv)
}

func TestTunnelCarriesATCPConnection(t *testing.T) {
	resolver, pub := startServer(t, startEcho(t))

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	s, err := client.Open(ctx, client.Config{Domain: zone, PubKey: pub, Resolver: resolver})
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()

	// A local TCP pair: one end goes into the tunnel, the test talks on the other.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	accepted := make(chan *net.TCPConn, 1)
	go func() {
		c, err := ln.Accept()
		if err == nil {
			accepted <- c.(*net.TCPConn)
		}
	}()
	app, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer app.Close()
	local := <-accepted
	defer local.Close()
	forwarded := make(chan error, 1)
	go func() { forwarded <- s.Forward(local) }()

	want := []byte("hello through the DNS tunnel")
	if _, err := app.Write(want); err != nil {
		t.Fatal(err)
	}
	app.SetReadDeadline(time.Now().Add(15 * time.Second))
	got := make([]byte, len(want))
	if _, err := io.ReadFull(app, got); err != nil {
		t.Fatalf("reading the echo: %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("echo = %q, want %q", got, want)
	}

	// A bigger transfer, to cross many DNS messages.
	big := make([]byte, 20_000)
	for i := range big {
		big[i] = byte(i * 7)
	}
	go app.Write(big)
	back := make([]byte, len(big))
	if _, err := io.ReadFull(app, back); err != nil {
		t.Fatalf("reading the bigger echo: %v", err)
	}
	for i := range big {
		if back[i] != big[i] {
			t.Fatalf("byte %d differs", i)
		}
	}
	app.Close()
	select {
	case <-forwarded:
	case <-time.After(10 * time.Second):
		t.Fatal("the forward did not end after the app closed")
	}
}

func TestProbe(t *testing.T) {
	resolver, pub := startServer(t, startEcho(t))

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	d, err := client.Probe(ctx, client.Config{Domain: zone, PubKey: pub, Resolver: resolver})
	if err != nil || d <= 0 {
		t.Fatalf("probe = %v, %v", d, err)
	}

	// A key that is not the server's does not get through.
	other, _ := noise.GeneratePrivkey()
	short, cancel2 := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel2()
	if _, err := client.Probe(short, client.Config{Domain: zone, PubKey: noise.PubkeyFromPrivkey(other), Resolver: resolver}); err == nil {
		t.Fatal("a probe with the wrong key should fail")
	}

	// Nothing there at all.
	short2, cancel3 := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel3()
	if _, err := client.Probe(short2, client.Config{Domain: zone, PubKey: pub, Resolver: "udp://127.0.0.1:9"}); err == nil {
		t.Fatal("a probe of a dead resolver should fail")
	}
}

func TestResolverAddresses(t *testing.T) {
	for _, ok := range []string{"udp://1.1.1.1:53", "udp://[2001:4860:4860::8888]:53", "tls://dns.google:853", "https://dns.google/dns-query", "https://1.1.1.1/dns-query"} {
		if _, err := client.ParseResolver(ok); err != nil {
			t.Errorf("%s: %v", ok, err)
		}
	}
	for _, bad := range []string{"", "1.1.1.1", "udp://dns.google:53", "udp://1.1.1.1", "tls://dns.google", "http://dns.google/dns-query", "tcp://1.1.1.1:53", "https://"} {
		if _, err := client.ParseResolver(bad); err == nil {
			t.Errorf("%q should be refused", bad)
		}
	}
}
