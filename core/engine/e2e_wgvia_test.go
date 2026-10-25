//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"testing"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"golang.org/x/crypto/curve25519"

	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// wgKeys makes a WireGuard key pair (base64, as configs carry them).
func wgKeys(t *testing.T) (priv, pub string) {
	t.Helper()
	var k [32]byte
	if _, err := rand.Read(k[:]); err != nil {
		t.Fatal(err)
	}
	k[0] &= 248
	k[31] = (k[31] & 127) | 64
	p, err := curve25519.X25519(k[:], curve25519.Basepoint)
	if err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(k[:]), base64.StdEncoding.EncodeToString(p)
}

// startBox runs a sing-box instance from a full config map.
func startBox(t *testing.T, cfg map[string]any) {
	t.Helper()
	ctx, cancel := context.WithCancel(include.Context(context.Background()))
	t.Cleanup(cancel)
	opts, err := parseOptions(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	b, err := box.New(box.Options{Context: ctx, Options: opts})
	if err != nil {
		t.Fatal(err)
	}
	if err := b.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { b.Close() })
}

// redirect is a route rule that sends what is aimed at from:port to a local address, so a test can use public-looking
// addresses that only the right path can reach.
func redirect(from string, fromPort int, toPort int, network string) map[string]any {
	return map[string]any{
		"ip_cidr": []any{from + "/32"}, "port": fromPort, "network": network,
		"action": "route-options", "override_address": "127.0.0.1", "override_port": toPort,
	}
}

// TestEndToEndWireGuardThroughProxy runs WireGuard inside a Shadowsocks proxy: the WireGuard server's address is
// reachable only through the proxy (which redirects it), so a page can load only if the client really sends its
// WireGuard packets through the proxy.
func TestEndToEndWireGuardThroughProxy(t *testing.T) {
	// The web page the tunnel is for.
	web := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "hello through the tunnel")
	})}
	webLn, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go web.Serve(webLn)
	t.Cleanup(func() { web.Close() })
	webPort := webLn.Addr().(*net.TCPAddr).Port

	// The WireGuard server; what the tunnel asks for at 203.0.113.10:80 is the web page.
	srvPriv, srvPub := wgKeys(t)
	cliPriv, cliPub := wgKeys(t)
	wgPort := freeUDPPort(t) // it is a UDP socket: a port free for TCP may not be for UDP (Windows runners)
	startBox(t, map[string]any{
		"log": map[string]any{"level": "error"},
		"endpoints": []any{map[string]any{
			"type": "wireguard", "tag": "wg-in", "address": []any{"10.9.0.1/24"}, "private_key": srvPriv, "listen_port": wgPort,
			"peers": []any{map[string]any{"public_key": cliPub, "allowed_ips": []any{"10.9.0.2/32"}}},
		}},
		"outbounds": []any{map[string]any{"type": "direct", "tag": "direct"}},
		"route": map[string]any{
			"rules": []any{redirect("203.0.113.10", 80, webPort, "tcp")},
			"final": "direct",
		},
	})

	// The proxy. 198.51.100.7:51820 does not exist; the proxy redirects it to the WireGuard server.
	ssPort := freePort(t)
	startBox(t, map[string]any{
		"log": map[string]any{"level": "error"},
		"inbounds": []any{map[string]any{
			"type": "shadowsocks", "listen": "127.0.0.1", "listen_port": ssPort, "method": "aes-128-gcm", "password": "test-pass",
		}},
		"outbounds": []any{map[string]any{"type": "direct", "tag": "direct"}},
		"route": map[string]any{
			"rules": []any{redirect("198.51.100.7", 51820, wgPort, "udp")},
			"final": "direct",
		},
	})

	fetch := func(t *testing.T, via string) error {
		t.Helper()
		p := &profile.Profile{Name: "wg", Protocol: profile.WireGuard, Server: "198.51.100.7", Port: 51820,
			WireGuard: &profile.WG{PrivateKey: cliPriv, PeerPublicKey: srvPub, Address: []string{"10.9.0.2/32"}, Via: via}}
		if err := p.Validate(); err != nil {
			t.Fatal(err)
		}
		p.EnsureID()
		proxyPort := freePort(t)
		e := New(Config{DataDir: tempDir(t), CertificateStore: "mozilla"})
		if err := e.Start(p.AsSlice(), singbox.Options{ListenPort: proxyPort, LogLevel: "error", Selected: p.ID, ProxyPrivate: true}); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { e.Stop() })

		proxyURL, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
		client := &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL), DisableKeepAlives: true}, Timeout: 8 * time.Second}
		resp, err := client.Get("http://203.0.113.10:80/data")
		if err != nil {
			return err
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		if string(body) != "hello through the tunnel" {
			t.Fatalf("body = %q", body)
		}
		return nil
	}

	via := fmt.Sprintf("ss://aes-128-gcm:test-pass@127.0.0.1:%d#proxy", ssPort)
	t.Run("through the proxy", func(t *testing.T) {
		if err := fetch(t, via); err != nil {
			t.Fatal(err)
		}
	})
	t.Run("without the proxy the server is unreachable", func(t *testing.T) {
		if err := fetch(t, ""); err == nil {
			t.Fatal("the WireGuard server should not be reachable without the proxy")
		}
	})
}
