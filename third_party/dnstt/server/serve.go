package server

// This file replaces upstream's dnstt-server/main.go: the same server as a library. Differences are listed in
// PATCHES.md.

import (
	"context"
	"fmt"
	"net"
	"sync/atomic"

	"github.com/NoobforAl/omnitun/third_party/dnstt/dns"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
)

var logger atomic.Pointer[func(format string, args ...any)]

// SetLogf sets where the package logs (nothing by default). It is shared by every server.
func SetLogf(f func(format string, args ...any)) {
	if f == nil {
		logger.Store(nil)
		return
	}
	logger.Store(&f)
}

func logf(format string, args ...any) {
	if f := logger.Load(); f != nil {
		(*f)(format, args...)
	}
}

// Config describes a tunnel server.
type Config struct {
	// Domain is the DNS zone the server is authoritative for.
	Domain string
	// PrivKey is the server's private key (noise.KeyLen bytes).
	PrivKey []byte
	// Upstream is the TCP address ("host:port") each tunnel stream is connected to.
	Upstream string
}

// Serve answers the tunnel's DNS queries arriving on conn (a UDP socket, usually port 53) until ctx ends or conn
// fails. It closes conn before it returns.
func Serve(ctx context.Context, conn net.PacketConn, cfg Config) error {
	domain, err := dns.ParseName(cfg.Domain)
	if err != nil {
		conn.Close()
		return fmt.Errorf("invalid domain %+q: %v", cfg.Domain, err)
	}
	if len(cfg.PrivKey) != noise.KeyLen {
		conn.Close()
		return fmt.Errorf("the server key must be %d bytes", noise.KeyLen)
	}
	if _, _, err := net.SplitHostPort(cfg.Upstream); err != nil {
		conn.Close()
		return fmt.Errorf("upstream %q: %v", cfg.Upstream, err)
	}
	stop := make(chan struct{})
	defer close(stop)
	go func() {
		select {
		case <-ctx.Done():
			conn.Close() // ends the receive loop, which ends run
		case <-stop:
		}
	}()
	return run(cfg.PrivKey, domain, cfg.Upstream, conn)
}
