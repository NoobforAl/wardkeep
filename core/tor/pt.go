package tor

import (
	"errors"
	"fmt"
	"io"
	"net"
	"sync"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/common/socks5"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/transports/base"
)

var initOnce sync.Once
var initErr error

// Supported are the pluggable transports the core can run.
var Supported = []string{"obfs4", "webtunnel", "snowflake", "meek_lite"}

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
}

// StartTransports starts a SOCKS5 listener for each named transport.
func StartTransports(stateDir string, names []string, dial DialFunc) (*Transports, error) {
	initOnce.Do(func() { initErr = transports.Init() })
	if initErr != nil {
		return nil, initErr
	}
	if dial == nil {
		dial = net.Dial
	}
	pts := &Transports{Addrs: map[string]string{}}
	for _, name := range names {
		if _, done := pts.Addrs[name]; done {
			continue
		}
		tr := transports.Get(name)
		if tr == nil {
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
	go func() { io.Copy(remote, conn); done <- struct{}{} }()
	go func() { io.Copy(conn, remote); done <- struct{}{} }()
	<-done
}

// Close stops all listeners (open connections end with their peers).
func (t *Transports) Close() error {
	var errs []error
	for _, ln := range t.listeners {
		errs = append(errs, ln.Close())
	}
	t.wg.Wait()
	return errors.Join(errs...)
}
