//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"context"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
	"github.com/NoobforAl/omnitun/third_party/dnstt/server"
)

// startDNSTTServer runs a dnstt server on loopback UDP in front of a SOCKS5 upstream that wants user/password, the
// way omnitun-server sets it up, and returns the resolver address and the server key.
func startDNSTTServer(t *testing.T, zone string) (resolver, keyHex string) {
	t.Helper()
	upstreamPort := freePort(t)
	startServer(t, map[string]any{
		"type": "socks", "listen": "127.0.0.1", "listen_port": upstreamPort,
		"users": []any{map[string]any{"username": "u", "password": "p"}},
	})
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
		server.Serve(ctx, pc, server.Config{Domain: zone, PrivKey: priv, Upstream: "127.0.0.1:" + strconv.Itoa(upstreamPort)})
	}()
	t.Cleanup(func() {
		cancel()
		<-done
	})
	return "udp://" + pc.LocalAddr().String(), noise.EncodeKey(noise.PubkeyFromPrivkey(priv))
}

// fetchViaDNSTT starts the engine on a DNS tunnel profile and loads a page through its proxy port.
func fetchViaDNSTT(t *testing.T, p *profile.Profile, webAddr string, within time.Duration) error {
	t.Helper()
	if err := p.Validate(); err != nil {
		t.Fatal(err)
	}
	p.EnsureID()
	proxyPort := freePort(t)
	e := New(Config{DataDir: tempDir(t), CertificateStore: "mozilla"})
	err := e.Start(p.AsSlice(), singbox.Options{
		ListenPort: proxyPort, LogLevel: "error", Selected: p.ID,
		TestURL:      "http://" + webAddr + "/probe",
		ProxyPrivate: true, // the web server is on loopback; force it through the tunnel
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { e.Stop() })

	proxyURL, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
	client := &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL), DisableKeepAlives: true}, Timeout: within}
	resp, err := client.Get("http://" + webAddr + "/data")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "hello through the DNS tunnel" {
		t.Fatalf("body = %q", body)
	}
	return nil
}

func startWeb(t *testing.T) string {
	t.Helper()
	web := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "hello through the DNS tunnel")
	})}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go web.Serve(ln)
	t.Cleanup(func() { web.Close() })
	return ln.Addr().String()
}

// TestEndToEndDNSTT loads a page through the real client engine and a real DNS tunnel server: the profile's
// resolver is the server itself (all a resolver does is pass the queries on), and the server's upstream is a
// SOCKS5 inbound that wants the profile's login.
func TestEndToEndDNSTT(t *testing.T) {
	const zone = "t.example.com"
	web := startWeb(t)
	resolver, key := startDNSTTServer(t, zone)

	good := &profile.Profile{Name: "dns", Protocol: profile.DNSTT, Server: zone, Port: 53, Username: "u", Password: "p",
		DNSTT: &profile.DNSTTOpts{Domain: zone, PubKey: key, Resolvers: []string{"udp://127.0.0.1:9", resolver}}}
	if err := fetchViaDNSTT(t, good, web, 30*time.Second); err != nil {
		t.Fatalf("through the DNS tunnel: %v", err)
	}

	// The upstream's login is checked: the wrong password gets nowhere.
	bad := &profile.Profile{Name: "dns", Protocol: profile.DNSTT, Server: zone, Port: 53, Username: "u", Password: "wrong",
		DNSTT: &profile.DNSTTOpts{Domain: zone, PubKey: key, Resolvers: []string{resolver}}}
	if err := fetchViaDNSTT(t, bad, web, 10*time.Second); err == nil {
		t.Fatal("a wrong login should not reach the web server")
	}
}

// A DNS tunnel profile that is not selected does not run, and is not an error for the other profiles.
func TestDNSTTProfileRunsOnlyWhenSelected(t *testing.T) {
	const zone = "t.example.com"
	web := startWeb(t)
	resolver, key := startDNSTTServer(t, zone)
	tunnel := &profile.Profile{Name: "dns", Protocol: profile.DNSTT, Server: zone, Port: 53, Username: "u", Password: "p",
		DNSTT: &profile.DNSTTOpts{Domain: zone, PubKey: key, Resolvers: []string{resolver}}}
	ssPort := freePort(t)
	startServer(t, map[string]any{"type": "shadowsocks", "listen": "127.0.0.1", "listen_port": ssPort,
		"method": "aes-128-gcm", "password": "test-pass", "network": "tcp"})
	ss := &profile.Profile{Name: "ss", Protocol: profile.Shadowsocks, Server: "127.0.0.1", Port: ssPort, Method: "aes-128-gcm", Password: "test-pass"}
	for _, p := range []*profile.Profile{tunnel, ss} {
		p.EnsureID()
	}

	proxyPort := freePort(t)
	e := New(Config{DataDir: tempDir(t), CertificateStore: "mozilla"})
	if err := e.Start([]*profile.Profile{tunnel, ss}, singbox.Options{ListenPort: proxyPort, LogLevel: "error", Selected: ss.ID, ProxyPrivate: true}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { e.Stop() })
	if _, _, ok := e.DNSTTStatus(); ok {
		t.Fatal("no DNS tunnel should run while another profile is selected")
	}
	if st := e.State(); len(st.Skipped) != 0 {
		t.Fatalf("an idle DNS tunnel profile should not be reported as skipped: %v", st.Skipped)
	}
	proxyURL, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
	client := &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL), DisableKeepAlives: true}, Timeout: 8 * time.Second}
	resp, err := client.Get("http://" + web + "/data")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()

	// Selecting the tunnel restarts into it, and the tunnel's resolver is reported.
	if err := e.Select(tunnel.ID); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(20 * time.Second)
	for {
		if res, _, ok := e.DNSTTStatus(); ok && res != "" {
			if !strings.HasPrefix(res, "udp://127.0.0.1:") {
				t.Fatalf("resolver = %q", res)
			}
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("the DNS tunnel did not come up after it was selected")
		}
		time.Sleep(100 * time.Millisecond)
	}

	// And selecting another profile again stops it.
	if err := e.Select(ss.ID); err != nil {
		t.Fatal(err)
	}
	if _, _, ok := e.DNSTTStatus(); ok {
		t.Fatal("the DNS tunnel should stop when another profile is selected")
	}
}
