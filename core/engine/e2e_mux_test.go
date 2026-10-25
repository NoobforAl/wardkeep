//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// muxRequest connects a client engine to a Shadowsocks server on localhost (multiplexing allowed there or
// not) with the given link parameters and sends parallel requests through its proxy port. It returns how many
// of them got the right answer.
func muxRequest(t *testing.T, serverMux bool, linkParams string, requests int) int {
	t.Helper()
	web := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "hello through the tunnel")
	})}
	webLn, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go web.Serve(webLn)
	t.Cleanup(func() { web.Close() })

	ssPort := freePort(t)
	in := map[string]any{
		"type": "shadowsocks", "listen": "127.0.0.1", "listen_port": ssPort,
		"method": "aes-128-gcm", "password": "test-pass", "network": "tcp",
	}
	if serverMux {
		in["multiplex"] = map[string]any{"enabled": true}
	}
	startServer(t, in)

	res, err := importer.Import(fmt.Sprintf("ss://aes-128-gcm:test-pass@127.0.0.1:%d?%s#mux", ssPort, linkParams))
	if err != nil {
		t.Fatal(err)
	}
	proxyPort := freePort(t)
	e := New(Config{DataDir: tempDir(t), CertificateStore: "mozilla"})
	err = e.Start(res.Profiles, singbox.Options{
		ListenPort:   proxyPort,
		LogLevel:     "error",
		Selected:     res.Profiles[0].ID,
		ProxyPrivate: true, // the web server is on loopback; force it through the tunnel
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { e.Stop() })

	proxyURL, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
	client := &http.Client{
		Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL), DisableKeepAlives: true},
		Timeout:   4 * time.Second,
	}
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for range requests {
		wg.Go(func() {
			resp, err := client.Get("http://" + webLn.Addr().String() + "/data")
			if err != nil {
				return
			}
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			if string(body) == "hello through the tunnel" {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		})
	}
	wg.Wait()
	return ok
}

// TestEndToEndMultiplex sends parallel requests through each multiplexing protocol, and shows the client
// really multiplexes: against a server that does not allow it, nothing gets through.
func TestEndToEndMultiplex(t *testing.T) {
	for _, params := range []string{
		"mux=smux&muxpad=1",
		"mux=yamux&muxconn=2&muxmin=4",
		"mux=h2mux&muxmax=8",
	} {
		t.Run(params, func(t *testing.T) {
			if got := muxRequest(t, true, params, 12); got != 12 {
				t.Fatalf("%d of 12 requests worked through %s", got, params)
			}
		})
	}
	t.Run("server without multiplexing", func(t *testing.T) {
		if got := muxRequest(t, false, "mux=smux", 3); got != 0 {
			t.Fatalf("%d requests worked although the server does not allow multiplexing, so the client is not multiplexing", got)
		}
	})
	t.Run("no multiplexing", func(t *testing.T) {
		if got := muxRequest(t, false, "", 3); got != 3 {
			t.Fatalf("%d of 3 plain requests worked", got)
		}
	})
}
