//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/wardkeep/core/importer"
	"github.com/NoobforAl/wardkeep/core/singbox"
)

// deadLinks are one link of each kind of server, all pointing at a port where nothing listens: a request only
// works if the rules send it around the VPN.
func deadLinks(t *testing.T) []string {
	t.Helper()
	tcp, udp := freePort(t), freeUDPPort(t)
	uuid := "b831381d-6324-4d53-ad4f-8cda48b30811"
	ss := "chacha20-ietf-poly1305:pass"
	return []string{
		fmt.Sprintf("vless://%s@127.0.0.1:%d?security=reality&sni=www.microsoft.com&fp=chrome&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=12ab&flow=xtls-rprx-vision#vless-reality", uuid, tcp),
		fmt.Sprintf("vless://%s@127.0.0.1:%d?security=tls&type=ws&path=%%2Fws&sni=example.com#vless-ws", uuid, tcp),
		"vmess://" + vmessLink(uuid, tcp),
		fmt.Sprintf("trojan://secret@127.0.0.1:%d?security=tls&sni=example.com#trojan", tcp),
		fmt.Sprintf("ss://%s@127.0.0.1:%d#shadowsocks", b64(ss), tcp),
		fmt.Sprintf("hy2://pw@127.0.0.1:%d?sni=example.com&insecure=1#hysteria2", udp),
		fmt.Sprintf("hysteria://127.0.0.1:%d?protocol=udp&auth=pw&peer=example.com&insecure=1&upmbps=10&downmbps=50#hysteria", udp),
		fmt.Sprintf("tuic://%s:pw@127.0.0.1:%d?congestion_control=bbr&sni=example.com&allow_insecure=1#tuic", uuid, udp),
		fmt.Sprintf("anytls://pw@127.0.0.1:%d/?sni=example.com&insecure=1#anytls", tcp),
		fmt.Sprintf("wireguard://yAnz5TF%%2BlXXJte14tji3zlMNq%%2Bhd2rYUIgJBgB3fBmk%%3D@127.0.0.1:%d?publickey=xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg%%3D&address=10.0.0.2%%2F32#wireguard", udp),
	}
}

func b64(s string) string { return base64.StdEncoding.EncodeToString([]byte(s)) }

func vmessLink(uuid string, port int) string {
	return b64(fmt.Sprintf(`{"v":"2","ps":"vmess","add":"127.0.0.1","port":"%d","id":"%s","aid":"0","net":"tcp","tls":""}`, port, uuid))
}

// serveText answers every request with body, on host (127.0.0.1, 127.0.0.2, ...).
func serveText(t *testing.T, host, body string) string {
	t.Helper()
	ln, err := net.Listen("tcp", net.JoinHostPort(host, "0"))
	if err != nil {
		t.Skipf("cannot listen on %s: %v", host, err)
	}
	srv := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, body) })}
	go srv.Serve(ln)
	t.Cleanup(func() { srv.Close() })
	return ln.Addr().String()
}

// fetchVia gets http://addr/ through the engine's SOCKS port, on a new connection each time.
func fetchVia(proxyPort int, addr string, timeout time.Duration) (string, error) {
	proxy, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
	client := &http.Client{
		Transport: &http.Transport{Proxy: http.ProxyURL(proxy), DisableKeepAlives: true},
		Timeout:   timeout,
	}
	resp, err := client.Get("http://" + addr + "/")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	return string(b), err
}

// The bypass list decides the route the same way whatever kind of server is in use: a listed address goes around
// the (dead) VPN and works, one that is not listed goes into it and fails; "only listed use the VPN" turns that
// around. Tor, dnstt, OpenVPN and the others reach the same rules (they run before the server is picked).
func TestBypassWorksForEveryConnectionType(t *testing.T) {
	listed := serveText(t, "127.0.0.1", "listed")
	other := serveText(t, "127.0.0.2", "other")
	parsed, issues := singbox.ParseBypassList("127.0.0.1\n")
	if len(issues) != 0 {
		t.Fatal(issues)
	}
	for _, link := range deadLinks(t) {
		res, err := importer.Import(link)
		if err != nil {
			t.Fatalf("import %s: %v", link, err)
		}
		p := res.Profiles[0]
		t.Run(p.Name, func(t *testing.T) {
			for _, only := range []bool{false, true} {
				port := freePort(t)
				e := New(Config{DataDir: tempDir(t), SkipHandshake: true})
				if err := e.Start(res.Profiles, singbox.Options{
					ListenPort: port, LogLevel: "error", Selected: p.ID, ProxyPrivate: true,
					Bypass: parsed, BypassOnly: only,
				}); err != nil {
					t.Fatal(err)
				}
				direct, vpn := listed, other
				if only {
					direct, vpn = other, listed
				}
				if body, err := fetchVia(port, direct, 5*time.Second); err != nil || (body != "listed" && body != "other") {
					t.Errorf("only=%v: %s should go direct: %q %v", only, direct, body, err)
				}
				if body, err := fetchVia(port, vpn, 3*time.Second); err == nil {
					t.Errorf("only=%v: %s went direct instead of into the VPN: %q", only, vpn, body)
				}
				e.Stop()
			}
		})
	}
}

// TestBypassPerformance measures what a bypass list costs, with the real address lists of countries
// (WARDKEEP_ZONES: a folder of <cc>.txt files, one range per line, as ipdeny.com serves them). It reports and
// does not judge: run with WARDKEEP_PERF=1 and -v.
func TestBypassPerformance(t *testing.T) {
	if os.Getenv("WARDKEEP_PERF") == "" {
		t.Skip("set WARDKEEP_PERF=1 (and WARDKEEP_ZONES) to measure")
	}
	zones := os.Getenv("WARDKEEP_ZONES")
	read := func(cc string) string {
		b, err := os.ReadFile(filepath.Join(zones, cc+".txt")) //nolint:gosec // G703: a folder the developer names for a measurement
		if err != nil {
			t.Skipf("no list for %s: %v", cc, err)
		}
		return string(b)
	}
	cases := []struct{ name, text string }{
		{"none", ""},
		{"Iran", read("ir")},
		{"China", read("cn")},
		{"US", read("us")},
		{"Iran+China+US", read("ir") + read("cn") + read("us")},
	}

	listed := serveText(t, "127.0.0.1", "listed")
	res, err := importer.Import(fmt.Sprintf("ss://%s@127.0.0.1:%d#dead", b64("chacha20-ietf-poly1305:pass"), freePort(t)))
	if err != nil {
		t.Fatal(err)
	}

	t.Logf("%-14s %8s %8s %9s %9s %9s %10s %9s %9s", "list", "ranges", "after", "parse", "build", "start", "heap", "req p50", "req p95")
	for _, c := range cases {
		for _, only := range []bool{false, true} {
			text := c.text + "127.0.0.1/32\n"

			start := time.Now()
			parsed, _ := singbox.ParseBypassList(text)
			parse := time.Since(start)
			kept := len(parsed.Optimized().CIDRs)

			start = time.Now()
			if _, _, err := singbox.Build(res.Profiles, singbox.Options{Mode: singbox.ModeTUN, Bypass: parsed, BypassOnly: only}); err != nil {
				t.Fatal(err)
			}
			build := time.Since(start)

			runtime.GC()
			var before runtime.MemStats
			runtime.ReadMemStats(&before)
			port := freePort(t)
			e := New(Config{DataDir: tempDir(t), SkipHandshake: true})
			start = time.Now()
			if err := e.Start(res.Profiles, singbox.Options{
				ListenPort: port, LogLevel: "error", Selected: res.Profiles[0].ID, ProxyPrivate: true,
				Bypass: parsed, BypassOnly: only,
			}); err != nil {
				t.Fatal(err)
			}
			started := time.Since(start)
			runtime.GC()
			var after runtime.MemStats
			runtime.ReadMemStats(&after)

			// New connections to the listed (direct) server: each one goes through the rules again.
			target := listed
			if only {
				// With "only listed use the VPN" the direct path is everything not listed.
				target = serveText(t, "127.0.0.2", "other")
			}
			var times []time.Duration
			for range 300 {
				s := time.Now()
				if _, err := fetchVia(port, target, 5*time.Second); err != nil {
					t.Fatal(err)
				}
				times = append(times, time.Since(s))
			}
			slices.Sort(times)
			e.Stop()

			name := c.name
			if only {
				name += " (only)"
			}
			t.Logf("%-14s %8d %8d %9s %9s %9s %8.1fMB %9s %9s", name, strings.Count(text, "/"), kept,
				parse.Round(time.Millisecond), build.Round(time.Millisecond), started.Round(time.Millisecond),
				float64(int64(after.HeapAlloc)-int64(before.HeapAlloc))/(1<<20),
				times[len(times)/2].Round(10*time.Microsecond), times[len(times)*95/100].Round(10*time.Microsecond))
		}
	}
}
