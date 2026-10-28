package engine

import (
	"context"
	"fmt"
	"net"
	"sync/atomic"

	box "github.com/sagernet/sing-box"
	M "github.com/sagernet/sing/common/metadata"

	"github.com/NoobforAl/omnitun/core/dnstt"
	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
	dnsttclient "github.com/NoobforAl/omnitun/third_party/dnstt/client"
)

// dnsttRun is the DNS tunnel behind a selected DNS tunnel profile. Its local port is a SOCKS5 outbound of the
// sing-box tunnel; the tunnel's own sockets (to the DNS resolver) are opened through sing-box's direct outbound once
// the tunnel is up, so they are never inside the VPN they serve: the platform protects them (Android) or binds them
// to the physical interface (desktop), the way sing-box's own connections are.
type dnsttRun struct {
	profile *profile.Profile
	proc    *dnstt.Process
	cancel  context.CancelFunc
	// notified is set once a panic of the tunnel told the user, so watchDNSTT does not again.
	notified atomic.Bool
}

func (r *dnsttRun) stop() {
	r.proc.Stop()
	r.cancel()
}

// withoutDNSTT drops DNS tunnel profiles from a list: they run only when selected, with their helper.
func withoutDNSTT(profiles []*profile.Profile) []*profile.Profile {
	out := make([]*profile.Profile, 0, len(profiles))
	for _, p := range profiles {
		if p.Protocol != profile.DNSTT {
			out = append(out, p)
		}
	}
	return out
}

// dnsttConfig is the tunnel's configuration from a profile.
func dnsttConfig(p *profile.Profile) (dnstt.Config, error) {
	opts := p.DNSTT
	if opts == nil {
		return dnstt.Config{}, fmt.Errorf("the profile has no DNS tunnel settings")
	}
	return dnstt.Config{Domain: opts.Domain, PubKey: opts.PubKey, Resolvers: opts.Resolvers}, nil
}

// startDNSTTLocked starts the tunnel process and the sing-box tunnel that routes into it. The process connects once
// sing-box is up (bindDNSTTLocked), and the tunnel is reported connected when the handshake through it works.
// e.mu must be held.
func (e *Engine) startDNSTTLocked(prof *profile.Profile, profiles []*profile.Profile, opts singbox.Options) error {
	cfg, err := dnsttConfig(prof)
	if err != nil {
		return e.failLocked(StagePrepare, err)
	}
	// Fail closed: a DNS tunnel profile never silently falls back to another profile.
	opts.Failover = false
	ctx, cancel := context.WithCancel(context.Background())
	dnsttclient.SetLogf(func(format string, args ...any) {
		e.logWith(logrec.LevelDebug, logFields{source: logrec.SourceDNSTT}, format, args...)
	})
	var run *dnsttRun
	proc, err := dnstt.Start(ctx, cfg, dnstt.Options{
		Deferred: true,
		Logf: func(format string, args ...any) {
			e.logWith(logrec.LevelInfo, logFields{source: logrec.SourceDNSTT}, format, args...)
		},
		OnPanic: func(rec logrec.Record) {
			rec.Source = logrec.SourceDNSTT
			e.deliver(rec, false)
			if run != nil {
				run.notified.Store(true)
			}
		},
	})
	if err != nil {
		cancel()
		return e.failLocked(StagePrepare, err)
	}
	run = &dnsttRun{profile: prof, proc: proc, cancel: cancel}
	e.dnsttRun = run
	opts.Helpers = map[string]singbox.HelperSocks{prof.ID: {Addr: proc.Addr, Username: prof.Username, Password: prof.Password}}
	e.logWith(logrec.LevelInfo, logFields{source: logrec.SourceDNSTT}, "starting the DNS tunnel")
	if err := e.startSingboxLocked(profiles, opts, prof.ID); err != nil {
		if e.dnsttRun == run {
			e.dnsttRun = nil
		}
		run.stop()
		return err
	}
	go func() {
		defer e.recoverLoop("connect")
		e.watchDNSTT(run)
	}()
	return nil
}

// watchDNSTT ends the tunnel when the DNS tunnel ends while the engine did not stop it (it only does after a
// panic): nothing else would tell the user.
func (e *Engine) watchDNSTT(run *dnsttRun) {
	<-run.proc.Done()
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.dnsttRun != run {
		return // stopped by the engine
	}
	e.dnsttRun = nil
	if !run.notified.Load() {
		e.logWith(logrec.LevelError, logFields{source: logrec.SourceDNSTT, code: ErrDNSTTExited, err: run.proc.Err(), notify: true},
			"the DNS tunnel stopped on its own")
	}
	wasRunning := e.state.Status == StatusRunning
	e.teardownLocked()
	run.cancel()
	e.dropReported = true
	stage := StageHandshake
	if wasRunning {
		stage = StageConnected
	}
	e.setState(State{Status: StatusError, Error: "the DNS tunnel stopped", Selected: run.profile.ID, Progress: progress(stage, e.name(run.profile.ID))})
	e.dropReported = false
}

// bindDNSTTLocked gives the tunnel its sockets once the sing-box tunnel is up: connections and UDP sockets that
// leave through the direct outbound. With no such outbound the tunnel is left unbound, which means it never
// connects: it does not fall back to ordinary sockets, which could loop into the VPN or leak the resolver.
func (e *Engine) bindDNSTTLocked(instance *box.Box) {
	run := e.dnsttRun
	if run == nil {
		return
	}
	direct, ok := lookupDialer(instance, singbox.TagDirect)
	if !ok {
		e.logWith(logrec.LevelError, logFields{source: logrec.SourceDNSTT}, "the DNS tunnel has no way out: sing-box has no direct outbound")
		return
	}
	run.proc.Bind(
		func(ctx context.Context, network, addr string) (net.Conn, error) {
			return direct.DialContext(ctx, network, M.ParseSocksaddr(addr))
		},
		func(ctx context.Context, network, remote string) (net.PacketConn, error) {
			return direct.ListenPacket(ctx, M.ParseSocksaddr(remote))
		},
	)
}

// DNSTTStatus describes the DNS tunnel of the running tunnel; ok is false when none runs.
func (e *Engine) DNSTTStatus() (resolver string, lastErr error, ok bool) {
	e.mu.Lock()
	run := e.dnsttRun
	e.mu.Unlock()
	if run == nil {
		return "", nil, false
	}
	return run.proc.Active(), run.proc.Err(), true
}
