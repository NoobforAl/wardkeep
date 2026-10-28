package engine

import (
	"context"
	"fmt"
	"net/netip"
	"strings"
	"time"

	"github.com/NoobforAl/omnitun/core/awg"
	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// awgHandshakeTimeout is how long a new AmneziaWG tunnel may take to complete
// its first handshake before it counts as failed.
const awgHandshakeTimeout = 15 * time.Second

// awgRun is a running AmneziaWG tunnel and what is needed to restart it.
type awgRun struct {
	tunnel   *awg.Tunnel
	profile  *profile.Profile
	profiles []*profile.Profile
	opts     singbox.Options
	cancel   context.CancelFunc
}

func (r *awgRun) stop() {
	r.cancel()
	r.tunnel.Close()
}

func findProfile(profiles []*profile.Profile, id string) *profile.Profile {
	for _, p := range profiles {
		if p.ID == id {
			return p
		}
	}
	return nil
}

// awgTunRequest describes the VPN interface for an AmneziaWG profile.
func awgTunRequest(p *profile.Profile, opts singbox.Options) TunRequest {
	wg := p.WireGuard
	req := TunRequest{
		MTU:             uint32(wg.MTU),
		AutoRoute:       true,
		Inet4Address:    []string{},
		Inet6Address:    []string{},
		Inet4RouteRange: []string{},
		Inet6RouteRange: []string{},
		DNSServers:      []string{},
		IncludePackage:  append([]string{}, opts.IncludePackages...),
	}
	if req.MTU == 0 {
		req.MTU = 1280
	}
	if len(req.IncludePackage) == 0 {
		req.ExcludePackage = append([]string{}, opts.ExcludePackages...)
	}
	for _, a := range wg.Address {
		pfx, err := netip.ParsePrefix(strings.TrimSpace(a))
		if err != nil {
			addr, aerr := netip.ParseAddr(strings.TrimSpace(a))
			if aerr != nil {
				continue
			}
			pfx = netip.PrefixFrom(addr, addr.BitLen())
		}
		if pfx.Addr().Is4() {
			req.Inet4Address = append(req.Inet4Address, pfx.String())
		} else {
			req.Inet6Address = append(req.Inet6Address, pfx.String())
		}
	}
	allowed := wg.AllowedIPs
	if len(allowed) == 0 {
		allowed = []string{"0.0.0.0/0", "::/0"}
	}
	for _, a := range allowed {
		pfx, err := netip.ParsePrefix(strings.TrimSpace(a))
		if err != nil {
			continue
		}
		if pfx.Addr().Is4() {
			req.Inet4RouteRange = append(req.Inet4RouteRange, pfx.Masked().String())
		} else if len(req.Inet6Address) > 0 {
			// Routing IPv6 without an IPv6 address would blackhole it.
			req.Inet6RouteRange = append(req.Inet6RouteRange, pfx.Masked().String())
		}
	}
	for _, d := range wg.DNS {
		if addr, err := netip.ParseAddr(strings.TrimSpace(d)); err == nil {
			req.DNSServers = append(req.DNSServers, addr.String())
		}
	}
	if len(req.DNSServers) == 0 {
		req.DNSServers = []string{"1.1.1.1"}
	}
	if !opts.ProxyPrivate {
		// Private ranges named explicitly in AllowedIPs are routed on purpose.
		var keep []netip.Prefix
		for _, a := range singbox.ParsePrefixes(allowed) {
			if a.Bits() > 0 {
				keep = append(keep, a)
			}
		}
		applyLocalBypass(&req, keep)
	}
	return req
}

// startAWGLocked brings up an AmneziaWG tunnel for prof. e.mu must be held.
func (e *Engine) startAWGLocked(prof *profile.Profile, profiles []*profile.Profile, opts singbox.Options) error {
	fail := func(stage string, err error) error {
		e.logWith(logrec.LevelError, logFields{profile: prof.ID, err: err}, "%s failed", stageLabel[stage])
		err = fmt.Errorf("%s failed: %w", stageLabel[stage], err)
		e.setState(State{Status: StatusError, Error: err.Error(), Selected: prof.ID, Progress: progress(stage, e.name(prof.ID))})
		return err
	}
	if _, err := awg.UAPI(prof, netip.AddrPortFrom(netip.IPv4Unspecified(), 1)); err != nil {
		return fail(StagePrepare, err)
	}
	e.logWith(logrec.LevelInfo, logFields{profile: prof.ID}, "starting AmneziaWG")
	e.setState(State{Status: StatusStarting, Selected: prof.ID, Progress: progress(StageEngineStart, e.name(prof.ID))})
	rctx, rcancel := context.WithTimeout(context.Background(), 10*time.Second)
	endpoint, err := awg.ResolveEndpoint(rctx, prof)
	rcancel()
	if err != nil {
		return fail(StageEngineStart, err)
	}
	fd, err := e.cfg.Tun.OpenTun(awgTunRequest(prof, opts))
	if err != nil {
		return fail(StageTunnelUp, err)
	}
	tunnel, err := awg.Start(prof, endpoint, fd, e.cfg.Tun.Protect, func(format string, args ...any) {
		e.logf("warn", format, args...)
	})
	if err != nil {
		return fail(StageTunnelUp, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	run := &awgRun{tunnel: tunnel, profile: prof, profiles: profiles, opts: opts, cancel: cancel}
	e.awgRun = run
	if e.cfg.SkipHandshake {
		e.setState(State{Status: StatusRunning, Since: time.Now(), Selected: prof.ID, Progress: progress(StageConnected, e.name(prof.ID))})
	} else {
		e.setState(State{Status: StatusStarting, Selected: prof.ID, Progress: progress(StageHandshake, e.name(prof.ID))})
	}
	go func() {
		defer e.recoverLoop("connect")
		e.awgLoop(ctx, run)
	}()
	return nil
}

// awgLoop waits for the first handshake, then publishes traffic once a second.
// If the handshake doesn't happen and failover is on, it moves to the next profile.
func (e *Engine) awgLoop(ctx context.Context, run *awgRun) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	deadline := time.Now().Add(awgHandshakeTimeout)
	var last awg.Stats
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		st := run.tunnel.Stats()
		e.mu.Lock()
		if e.awgRun != run {
			e.mu.Unlock()
			return
		}
		state := e.state
		if state.Status == StatusStarting {
			switch {
			case !st.LastHandshake.IsZero():
				state.Status, state.Since, state.Progress = StatusRunning, time.Now(), progress(StageConnected, e.name(run.profile.ID))
				e.logWith(logrec.LevelInfo, logFields{profile: run.profile.ID}, "connected")
			case time.Now().After(deadline):
				e.awgHandshakeFailedLocked(run)
				e.mu.Unlock()
				return
			}
		}
		if state.Status == StatusRunning {
			state.UpBps, state.DownBps = st.TxBytes-last.TxBytes, st.RxBytes-last.RxBytes
			state.UpTotal, state.DownTotal = st.TxBytes, st.RxBytes
			last = st
		}
		e.setState(state)
		e.mu.Unlock()
	}
}

// awgHandshakeFailedLocked reports the failure, or fails over to the next
// profile in the user's order when failover is on. e.mu must be held.
func (e *Engine) awgHandshakeFailedLocked(run *awgRun) {
	reason := fmt.Errorf("no handshake from %s within %s", e.name(run.profile.ID), awgHandshakeTimeout)
	if run.opts.Failover && len(run.profiles) > 1 {
		next := rotateAfter(profileOrder(run.profiles), run.profile.ID)[0]
		e.logWith(logrec.LevelWarn, logFields{profile: run.profile.ID, code: ErrNoHandshake},
			"failover: no handshake within %s, trying the next profile (%s)", awgHandshakeTimeout, next)
		e.carryFailover = &FailoverEvent{From: run.profile.ID, To: next, Reason: reason.Error(), At: time.Now()}
		opts := run.opts
		opts.Selected = next
		// Don't loop back to this profile if the rest fail too.
		rest := make([]*profile.Profile, 0, len(run.profiles)-1)
		for _, p := range run.profiles {
			if p.ID != run.profile.ID {
				rest = append(rest, p)
			}
		}
		e.startLocked(rest, opts)
		return
	}
	e.stopLocked()
	err := fmt.Errorf("%s failed: %w", stageLabel[StageHandshake], reason)
	e.logWith(logrec.LevelError, logFields{profile: run.profile.ID, code: ErrNoHandshake},
		"%s failed: no handshake within %s", stageLabel[StageHandshake], awgHandshakeTimeout)
	e.setState(State{Status: StatusError, Error: err.Error(), Selected: run.profile.ID, Progress: progress(StageHandshake, e.name(run.profile.ID))})
}
