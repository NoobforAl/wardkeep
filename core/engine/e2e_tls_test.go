//go:build with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"io"
	"math/big"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	singtls "github.com/sagernet/sing-box/common/tls"

	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// selfSigned makes a certificate for localhost and 127.0.0.1 and returns it and its key as PEM.
func selfSigned(t *testing.T) (certPEM, keyPEM string) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "localhost"},
		NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour),
		DNSNames: []string{"localhost"}, IPAddresses: []net.IP{net.ParseIP("127.0.0.1")},
		KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	keyDER, err := x509.MarshalECPrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	return string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})),
		string(pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER}))
}

func lines(s string) []any {
	var out []any
	for l := range strings.SplitSeq(strings.TrimSpace(s), "\n") {
		out = append(out, l)
	}
	return out
}

// trojanOverTLS connects a client engine to a local Trojan server whose TLS the test sets up, and fetches a page
// through the proxy port. clientTLS adds the handshake options under test.
func trojanOverTLS(t *testing.T, serverECHKey string, clientTLS func(*profile.TLS)) error {
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

	certPEM, keyPEM := selfSigned(t)
	srvTLS := map[string]any{"enabled": true, "server_name": "localhost", "certificate": lines(certPEM), "key": lines(keyPEM)}
	if serverECHKey != "" {
		srvTLS["ech"] = map[string]any{"enabled": true, "key": lines(serverECHKey)}
	}
	port := freePort(t)
	startServer(t, map[string]any{
		"type": "trojan", "listen": "127.0.0.1", "listen_port": port,
		"users": []any{map[string]any{"name": "u", "password": "pw"}}, "tls": srvTLS,
	})

	p := &profile.Profile{Name: "tls", Protocol: profile.Trojan, Server: "127.0.0.1", Port: port, Password: "pw",
		TLS: &profile.TLS{Enabled: true, ServerName: "localhost", Certificate: certPEM}}
	clientTLS(p.TLS)
	if err := p.Validate(); err != nil {
		t.Fatal(err)
	}
	p.EnsureID()

	proxyPort := freePort(t)
	e := New(Config{DataDir: tempDir(t), CertificateStore: "mozilla"})
	err = e.Start(p.AsSlice(), singbox.Options{ListenPort: proxyPort, LogLevel: "error", Selected: p.ID, ProxyPrivate: true})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { e.Stop() })

	proxyURL, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
	client := &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL), DisableKeepAlives: true}, Timeout: 5 * time.Second}
	resp, err := client.Get("http://" + webLn.Addr().String() + "/data")
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

// TestEndToEndFragmentedHandshake shows a Trojan connection still works when the TLS handshake is split into
// pieces, by packets, by records, or both.
func TestEndToEndFragmentedHandshake(t *testing.T) {
	for name, set := range map[string]func(*profile.TLS){
		"plain":           func(*profile.TLS) {},
		"fragment":        func(c *profile.TLS) { c.Fragment = true },
		"record fragment": func(c *profile.TLS) { c.RecordFragment = true },
		"both":            func(c *profile.TLS) { c.Fragment, c.RecordFragment = true, true },
		"both with uTLS":  func(c *profile.TLS) { c.Fragment, c.RecordFragment, c.Fingerprint = true, true, "chrome" },
	} {
		t.Run(name, func(t *testing.T) {
			if err := trojanOverTLS(t, "", set); err != nil {
				t.Fatal(err)
			}
		})
	}
}

// TestEndToEndECH connects with Encrypted Client Hello to a server that supports it, and shows the option is
// really used: without the server's key a client that asks for ECH cannot connect.
func TestEndToEndECH(t *testing.T) {
	configPEM, keyPEM, err := singtls.ECHKeygenDefault("public.example")
	if err != nil {
		t.Fatal(err)
	}
	if err := trojanOverTLS(t, keyPEM, func(c *profile.TLS) {
		c.ECH = &profile.ECH{Enabled: true, Config: configPEM}
	}); err != nil {
		t.Fatalf("with ECH: %v", err)
	}
	if err := trojanOverTLS(t, keyPEM, func(c *profile.TLS) {
		c.ECH = &profile.ECH{Enabled: true, Config: configPEM}
		c.Fragment, c.RecordFragment = true, true
	}); err != nil {
		t.Fatalf("with ECH and fragments: %v", err)
	}

	// A server with no ECH key does not understand a client that insists on it.
	if err := trojanOverTLS(t, "", func(c *profile.TLS) {
		c.ECH = &profile.ECH{Enabled: true, Config: configPEM}
	}); err == nil {
		t.Fatal("a server without ECH should refuse a client that requires it")
	}
}
