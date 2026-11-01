package tor

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"slices"
	"sync"
	"time"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/common/socks5"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
)

var initOnce sync.Once
var initErr error

// Supported are the pluggable transports the core can run.
var Supported = []string{"obfs4", "webtunnel", "snowflake"}

// DialFunc opens the transport's outbound connections (on Android these must
// bypass the VPN).
type DialFunc = base.DialFunc

// Transports runs pluggable transport clients in-process, each behind a local
// SOCKS5 port that Arti uses as an "unmanaged" transport (bridge arguments
// arrive in the SOCKS username/password, as the PT spec defines).
type Transports struct {
	Addrs     map[string]string // transport name -> 127.0.0.1:port
	listeners []net.Listener
	wg        sync.WaitGroup
	// ctx ends with Close, so a dial to a bridge still in flight does not outlive the transports.
	ctx    context.Context
	cancel context.CancelFunc
}

// ptDialTimeout bounds one dial to a bridge (an unreachable one otherwise waits for the system's own timeout).
const ptDialTimeout = 30 * time.Second

// StartTransports starts a SOCKS5 listener for each named transport.
func StartTransports(stateDir string, names []string, dial DialFunc) (*Transports, error) {
	initOnce.Do(func() { initErr = transports.Init() })
	if initErr != nil {
		return nil, initErr
	}
	ctx, cancel := context.WithCancel(context.Background())
	pts := &Transports{Addrs: map[string]string{}, ctx: ctx, cancel: cancel}
	dial = pts.bounded(dial)
	for _, name := range names {
		if _, done := pts.Addrs[name]; done {
			continue
		}
		// Only the transports in Supported: lyrebird also has others (meek_lite, obfs2, ...) that are not offered.
		tr := transports.Get(name)
		if tr == nil || !slices.Contains(Supported, name) {
			pts.Close()
			return nil, fmt.Errorf("unsupported bridge transport %q", name)
		}
		factory, err := tr.ClientFactory(stateDir)
		if err != nil {
			pts.Close()
			return nil, fmt.Errorf("%s: %w", name, err)
		}
		ln, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			pts.Close()
			return nil, err
		}
		pts.listeners = append(pts.listeners, ln)
		pts.Addrs[name] = ln.Addr().String()
		pts.wg.Go(func() {
			for {
				conn, err := ln.Accept()
				if err != nil {
					return
				}
				go handle(factory, conn, dial)
			}
		})
	}
	return pts, nil
}

func handle(factory base.ClientFactory, conn net.Conn, dial DialFunc) {
	defer conn.Close()
	req, err := socks5.Handshake(conn)
	if err != nil {
		return
	}
	args, err := factory.ParseArgs(&req.Args)
	if err != nil {
		_ = req.Reply(socks5.ReplyGeneralFailure)
		return
	}
	remote, err := factory.Dial("tcp", req.Target, dial, args)
	if err != nil {
		_ = req.Reply(socks5.ErrorToReplyCode(err))
		return
	}
	defer remote.Close()
	if err := req.Reply(socks5.ReplySucceeded); err != nil {
		return
	}
	done := make(chan struct{}, 2)
	go func() { _, _ = io.Copy(remote, conn); done <- struct{}{} }()
	go func() { _, _ = io.Copy(conn, remote); done <- struct{}{} }()
	<-done
}

// bounded makes dial give up after ptDialTimeout or when the transports close. The default dial is cancelled
// outright; a given one (Android's, which keeps the connection out of the VPN) cannot be, so the caller stops
// waiting for it and a connection that arrives late is closed.
func (t *Transports) bounded(dial DialFunc) DialFunc {
	if dial == nil {
		return func(network, addr string) (net.Conn, error) {
			ctx, cancel := context.WithTimeout(t.ctx, ptDialTimeout)
			defer cancel()
			var d net.Dialer
			return d.DialContext(ctx, network, addr)
		}
	}
	return func(network, addr string) (net.Conn, error) {
		type result struct {
			conn net.Conn
			err  error
		}
		done := make(chan result, 1)
		go func() {
			conn, err := dial(network, addr)
			done <- result{conn, err}
		}()
		timer := time.NewTimer(ptDialTimeout)
		defer timer.Stop()
		var err error
		select {
		case r := <-done:
			return r.conn, r.err
		case <-t.ctx.Done():
			err = net.ErrClosed
		case <-timer.C:
			err = fmt.Errorf("dial %s: timed out after %s", network, ptDialTimeout)
		}
		go func() {
			if r := <-done; r.conn != nil {
				_ = r.conn.Close()
			}
		}()
		return nil, err
	}
}

// Close stops all listeners and the dials in flight (open connections end with their peers).
func (t *Transports) Close() error {
	t.cancel()
	var errs []error
	for _, ln := range t.listeners {
		errs = append(errs, ln.Close())
	}
	t.wg.Wait()
	return errors.Join(errs...)
}
