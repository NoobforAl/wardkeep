package pprofsrv

import (
	"context"
	"io"
	"net/http"
	"testing"
	"time"
)

func TestListenRefusesNonLoopback(t *testing.T) {
	for _, addr := range []string{"0.0.0.0:0", "192.168.1.5:6060", ":6060", "example.com:6060", "no-port"} {
		if ln, err := Listen(addr); err == nil {
			ln.Close()
			t.Errorf("Listen(%q) succeeded, want an error", addr)
		}
	}
}

func TestServesProfiles(t *testing.T) {
	ln, err := Listen("127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- ServeListener(ctx, ln, nil) }()

	resp, err := http.Get("http://" + ln.Addr().String() + "/debug/pprof/goroutine?debug=1")
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != 200 || len(body) == 0 {
		t.Fatalf("goroutine profile: status %d, %d bytes", resp.StatusCode, len(body))
	}

	cancel()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("ServeListener returned %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("ServeListener did not stop after the context ended")
	}
}
