package engine

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/NoobforAl/omnitun/core/dnscrypt"
	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/singbox"
	box "github.com/sagernet/sing-box"
	M "github.com/sagernet/sing/common/metadata"
)

// dnsCryptRun is the DNSCrypt forwarder of a running sing-box tunnel. Its
// queries leave through the tunnel's selected outbound, so the network between
// this device and the VPN server sees neither the resolver nor the relay; the
// sockets are the outbound's own, which the platform already protects from the
// VPN (Android) or binds to the physical interface (desktop).
type dnsCryptRun struct {
	fwd *dnscrypt.Forwarder

	mu  sync.RWMutex
	out tunnelOutbound
}

// tunnelOutbound is what the forwarder needs from the tunnel: a sing-box outbound.
type tunnelOutbound interface {
	DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error)
}

var errTunnelNotUp = fmt.Errorf("the VPN tunnel is not up yet: %w", dnscrypt.ErrNotReady)

// dial is the forwarder's Dialer: through the tunnel, never around it.
func (r *dnsCryptRun) dial(ctx context.Context, network, address string) (net.Conn, error) {
	r.mu.RLock()
	out := r.out
	r.mu.RUnlock()
	if out == nil {
		return nil, errTunnelNotUp
	}
	return out.DialContext(ctx, network, M.ParseSocksaddr(address))
}

func (r *dnsCryptRun) setOutbound(out tunnelOutbound) {
	r.mu.Lock()
	r.out = out
	r.mu.Unlock()
}

// startDNSCryptLocked starts the forwarder when opts.DNS is a DNSCrypt stamp
// and points opts.DNSForwarder at it. Other settings need nothing.
func (e *Engine) startDNSCryptLocked(opts *singbox.Options) error {
	if !singbox.DNSNeedsForwarder(opts.DNS) {
		return nil
	}
	if err := singbox.CheckDNSRelay(opts.DNSRelay); err != nil {
		return err
	}
	run := &dnsCryptRun{}
	fwd, err := dnscrypt.NewForwarder(dnscrypt.ForwarderConfig{
		Stamp: opts.DNS,
		Relay: opts.DNSRelay,
		Dial:  run.dial,
		// Tor has no UDP; the same goes for outbounds that cannot carry it,
		// where the forwarder falls back by itself.
		TCPOnly: opts.TorSocks != "",
		Logf: func(level, format string, args ...any) {
			parsed, _ := logrec.ParseLevel(level)
			e.logWith(parsed, logFields{source: logrec.SourceDNSCrypt}, format, args...)
		},
	})
	if err != nil {
		return err
	}
	if err := fwd.Start(); err != nil {
		return err
	}
	run.fwd = fwd
	e.dnsRun = run
	opts.DNSForwarder = fwd.Addr()
	mode := ""
	if fwd.Anonymized() {
		mode = " through a relay (Anonymized DNSCrypt)"
	}
	e.logWith(logrec.LevelInfo, logFields{source: logrec.SourceDNSCrypt}, "DNS: DNSCrypt%s", mode)
	return nil
}

// bindDNSCryptLocked gives the forwarder its way out once the tunnel is up and
// checks the resolver in the background; a resolver that cannot be reached or
// whose key is wrong is logged as "DNS unavailable". Queries then fail
// (SERVFAIL): there is no fallback to a plain resolver.
func (e *Engine) bindDNSCryptLocked(instance *box.Box) {
	run := e.dnsRun
	if run == nil {
		return
	}
	if out, ok := lookupDialer(instance, singbox.TagSelect); ok {
		run.setOutbound(out)
		run.fwd.Retry() // queries that came before the tunnel did were refused
	}
	go func() {
		defer e.recoverLoop("connect")
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		if err := run.fwd.Check(ctx); err != nil {
			e.logWith(logrec.LevelError, logFields{source: logrec.SourceDNSCrypt, code: ErrDNS, err: err}, "DNS unavailable")
		}
	}()
}

// stopDNSCryptLocked closes the forwarder, if one runs.
func (e *Engine) stopDNSCryptLocked() {
	if run := e.dnsRun; run != nil {
		e.dnsRun = nil
		run.fwd.Close()
	}
}

// DNSStatus describes the DNSCrypt forwarder of the running tunnel; ok is false
// when no DNSCrypt resolver is in use.
func (e *Engine) DNSStatus() (resolver string, anonymized bool, stats dnscrypt.Stats, ok bool) {
	e.mu.Lock()
	run := e.dnsRun
	e.mu.Unlock()
	if run == nil {
		return "", false, dnscrypt.Stats{}, false
	}
	return run.fwd.Resolver(), run.fwd.Anonymized(), run.fwd.Stats(), true
}
