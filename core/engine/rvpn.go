package engine

import (
	"context"
	"errors"
	"path/filepath"
	"sync/atomic"
	"time"

	"github.com/NoobforAl/wardkeep/core/logrec"
	"github.com/NoobforAl/wardkeep/core/profile"
	"github.com/NoobforAl/wardkeep/core/rvpn"
	"github.com/NoobforAl/wardkeep/core/singbox"
)

// rvpnRun is the rVPN helper (wardkeep-rvpn) behind a selected rVPN profile. Its SOCKS5 port is an outbound of the
// sing-box tunnel; the helper connects to the rVPN server on the first connection through it, so the engine's
// usual handshake check (a test request through the profile) is what brings the tunnel up.
//
// The helper is a separate process that opens its own sockets to the server. On Android the app is kept out of its
// own VPN (as for Tor), so they reach the network directly instead of looping into the tunnel; a desktop TUN has no
// such exclusion, so rVPN is refused there (proxy mode works).
type rvpnRun struct {
	profile *profile.Profile
	proc    *rvpn.Process
	// notified is set once one of the helper's records told the user, so watchRVPN does not again.
	notified atomic.Bool
}

func (r *rvpnRun) stop() { r.proc.Stop() }

// withoutHelpers drops the helper-run profiles (DNS tunnel, rVPN) whose helper is not running: they only work
// while selected.
func withoutHelpers(profiles []*profile.Profile, helpers map[string]singbox.HelperSocks) []*profile.Profile {
	out := make([]*profile.Profile, 0, len(profiles))
	for _, p := range profiles {
		if p.Protocol == profile.DNSTT || p.Protocol == profile.RVPN {
			if _, ok := helpers[p.ID]; !ok {
				continue
			}
		}
		out = append(out, p)
	}
	return out
}

// errRVPNDesktopTUN refuses rVPN in a desktop TUN, where the helper's own connections would enter the tunnel.
var errRVPNDesktopTUN = errors.New(msgRVPNDesktopTUN)

// startRVPNLocked starts the helper and the sing-box tunnel that routes into it. e.mu must be held.
func (e *Engine) startRVPNLocked(prof *profile.Profile, profiles []*profile.Profile, opts singbox.Options) error {
	if opts.Mode == singbox.ModeTUN && e.cfg.Tun == nil {
		return e.failLocked(StagePrepare, errRVPNDesktopTUN)
	}
	// Fail closed: an rVPN profile never silently falls back to another profile.
	opts.Failover = false
	// rVPN is IPv4 in practice (its own clients route 0.0.0.0/0 and prefer IPv4), and a server without IPv6 never
	// refuses an IPv6 flow: the app's connection, already accepted by the TUN, hangs. IPv4 only, as the IPv6 setting's
	// "off": no AAAA answers, and IPv6 connections are refused at once (never sent around the VPN).
	opts.NoIPv6 = true
	if opts.Mode == singbox.ModeTUN && len(opts.IncludePackages) == 0 {
		opts.ExcludePackages = append(append([]string{}, opts.ExcludePackages...), singbox.SelfPackage)
	}
	run := &rvpnRun{profile: prof}
	proc, err := rvpn.Start(rvpn.Config{
		// One identity per profile: the server tells clients apart by this key.
		DataDir:  filepath.Join(e.dataDir(), "rvpn", prof.ID),
		Profile:  prof,
		LogLevel: torLogLevel(),
		OnLog:    func(rec logrec.Record) { e.rvpnRecord(run, rec) },
	})
	if err != nil {
		return e.failLocked(StagePrepare, err)
	}
	run.proc = proc
	e.rvpnRun = run
	opts.Helpers = map[string]singbox.HelperSocks{prof.ID: {Addr: proc.SocksAddr, Username: proc.Username, Password: proc.Password}}
	e.logWith(logrec.LevelInfo, logFields{source: logrec.SourceRVPN}, "starting rVPN")
	if err := e.startSingboxLocked(profiles, opts, prof.ID); err != nil {
		if e.rvpnRun == run {
			e.rvpnRun = nil
		}
		run.stop()
		return err
	}
	go func() {
		defer e.recoverLoop("connect")
		e.watchRVPN(run)
	}()
	return nil
}

// rvpnRecord passes on a record of the helper (scrubbed on the way, like every record).
func (e *Engine) rvpnRecord(run *rvpnRun, rec logrec.Record) {
	if rec.Level < logrec.LevelFatal && !logrec.Enabled(rec.Level) && !rec.Notify {
		return
	}
	if rec.Source == "" {
		rec.Source = logrec.SourceRVPN
	}
	if rec.Notify {
		run.notified.Store(true)
	}
	e.deliver(rec, false)
}

// rvpnFailure is why the helper could not connect, if it said so: the test request through it only sees a
// refused SOCKS request. The helper's error event can trail the refusal by a moment, so it is waited for briefly.
func (e *Engine) rvpnFailure(ctx context.Context) error {
	e.mu.Lock()
	run := e.rvpnRun
	e.mu.Unlock()
	if run == nil {
		return nil
	}
	deadline := time.Now().Add(time.Second)
	for {
		if he := run.proc.LastError(); he != nil {
			return he
		}
		if time.Now().After(deadline) {
			return nil
		}
		select {
		case <-ctx.Done():
			return nil
		case <-time.After(50 * time.Millisecond):
		}
	}
}

// watchRVPN ends the tunnel when the helper exits while the engine did not stop it: nothing else would tell the user.
func (e *Engine) watchRVPN(run *rvpnRun) {
	<-run.proc.Done()
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.rvpnRun != run {
		return // stopped by the engine
	}
	e.rvpnRun = nil
	if !run.notified.Load() {
		e.logWith(logrec.LevelError, logFields{source: logrec.SourceRVPN, code: ErrRVPNExited, err: run.proc.Err(), notify: true},
			"the rVPN client stopped on its own")
	}
	wasRunning := e.state.Status == StatusRunning
	_ = e.teardownLocked()
	e.dropReported = true
	stage := StageHandshake
	if wasRunning {
		stage = StageConnected
	}
	e.setState(State{Status: StatusError, Error: msgRVPNExited, Selected: run.profile.ID, Progress: progress(stage, e.name(run.profile.ID))})
	e.dropReported = false
}
