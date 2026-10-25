package control

import (
	"context"
	"errors"
	"net"
	"testing"

	"github.com/NoobforAl/omnitun/core/dnstt"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
	"github.com/NoobforAl/omnitun/third_party/dnstt/server"
)

// The editor's "find working resolvers": which of the candidates reach the tunnel server, best first.
func TestDNSTTScanMethod(t *testing.T) {
	priv, err := noise.GeneratePrivkey()
	if err != nil {
		t.Fatal(err)
	}
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	up, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer up.Close()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		server.Serve(ctx, pc, server.Config{Domain: "t.example.com", PrivKey: priv, Upstream: up.Addr().String()})
	}()
	defer func() {
		cancel()
		<-done
	}()
	resolver := "udp://" + pc.LocalAddr().String()

	s, addr := newTestServer(t, ServerConfig{})
	c, err := Dial(t.Context(), addr, s.Token())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	var res []dnstt.ScanResult
	err = c.Call(t.Context(), "dnstt_scan", DNSTTScanParams{
		Domain: "t.example.com", PubKey: noise.EncodeKey(noise.PubkeyFromPrivkey(priv)),
		Resolvers: []string{"udp://127.0.0.1:9", resolver},
	}, &res)
	if err != nil {
		t.Fatal(err)
	}
	if len(res) != 2 || res[0].Resolver != resolver || res[0].Ms <= 0 || res[1].Ms != 0 || res[1].Err == "" {
		t.Fatalf("scan = %+v", res)
	}

	var ce *Error
	err = c.Call(t.Context(), "dnstt_scan", DNSTTScanParams{Domain: "t.example.com", PubKey: "nonsense"}, nil)
	if !errors.As(err, &ce) || ce.Code != CodeBadRequest {
		t.Fatalf("a bad key: %v", err)
	}
}
