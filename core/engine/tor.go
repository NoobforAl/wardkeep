package engine

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync/atomic"
	"time"

	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
	"github.com/NoobforAl/omnitun/core/tor"
)

// Bootstrap progress fills this slice of the connection ring (between
// "preparing" and "opening the tunnel").
const (
	torPercentFrom = 25
	torPercentTo   = 63
)

// torRun is a Tor client started for a selected Tor profile. sing-box starts
// once it is ready and routes the profile into its SOCKS5 port.
type torRun struct {
	profile  *profile.Profile
	profiles []*profile.Profile
	opts     singbox.Options
	cancel   context.CancelFunc
	proc     *tor.Process
	// path is the circuit the traffic rides, as last reported by Tor (guarded by Engine.mu).
	path []TorHop
	// inUse is set once the tunnel runs on this Tor client; before, its failures are retried and the state reports
	// the last one, so its records do not notify.
	inUse atomic.Bool
	// notified is set once one of its records told the user (a crash of omnitun-tor), so watchTor does not again.
	notified atomic.Bool
}

func (r *torRun) stop() {
	r.cancel()
	if r.proc != nil {
		r.proc.Stop()
	}
}

// withoutTor drops Tor profiles from a list.
func withoutTor(profiles []*profile.Profile) []*profile.Profile {
	out := make([]*profile.Profile, 0, len(profiles))
	for _, p := range profiles {
		if p.Protocol != profile.Tor {
			out = append(out, p)
		}
	}
	return out
}

// torBridges lists the bridge lines a Tor profile uses.
func torBridges(prof *profile.Profile) ([]string, error) {
	if prof.Tor == nil {
		return nil, nil
	}
	bridges := append([]string{}, prof.Tor.Bridges...)
	for _, b := range bridges {
		if !hasFingerprint(b) {
			return nil, errNoFingerprint
		}
	}
	if k := prof.Tor.Builtin; k != "" {
		b := tor.Builtin(k)
		if len(b) == 0 {
			return nil, fmt.Errorf("unknown built-in bridge kind %q", k)
		}
		bridges = append(bridges, b...)
	}
	return bridges, nil
}

var fingerprintRE = regexp.MustCompile(`(?i)(^|\s)(fingerprint=)?[0-9a-f]{40}(\s|$)`)

// hasFingerprint reports whether a bridge line carries a relay fingerprint.
func hasFingerprint(line string) bool { return fingerprintRE.MatchString(line) }

// startTorLocked starts Tor in the background and reports its bootstrap as
// connection progress; the tunnel starts once Tor is ready. e.mu must be held.
func (e *Engine) startTorLocked(prof *profile.Profile, profiles []*profile.Profile, opts singbox.Options) error {
	if opts.Mode != singbox.ModeTUN && opts.Mode != singbox.ModeProxy {
		return e.failLocked(StagePrepare, fmt.Errorf("unknown mode %q", opts.Mode))
	}
	bridges, err := torBridges(prof)
	if err != nil {
		return e.failLocked(StagePrepare, err)
	}
	// Fail closed: a Tor profile never silently falls back to a non-Tor one
	// (that would drop the anonymity the user chose); the user picks another
	// profile themselves.
	opts.Failover = false
	// Tor and its bridge transports run as this app: in VPN mode keep the app
	// itself out of the VPN so they reach the network directly.
	if opts.Mode == singbox.ModeTUN && len(opts.IncludePackages) == 0 {
		opts.ExcludePackages = append(append([]string{}, opts.ExcludePackages...), singbox.SelfPackage)
	}

	ctx, cancel := context.WithTimeout(context.Background(), torAttempts*torAttemptTimeout+30*time.Second)
	run := &torRun{profile: prof, profiles: profiles, opts: opts, cancel: cancel}
	e.torRun = run
	name := e.name(prof.ID)
	e.logWith(logrec.LevelInfo, logFields{source: logrec.SourceTor, op: "bootstrap"}, "starting Tor")
	e.setState(State{Status: StatusStarting, Selected: prof.ID, Progress: &Progress{
		Stage: StageEngineStart, Percent: torPercentFrom, Profile: name, Detail: "Starting Tor", DetailCode: DetailTorStarting,
	}})

	// Each Tor profile keeps its own directory cache. Guard state is dropped on
	// every connect: on a network that blocks Tor, earlier failures mark every
	// guard "down" and Arti would refuse to try them again for a long time.
	torDir := filepath.Join(e.dataDir(), "tor", prof.ID)
	os.RemoveAll(filepath.Join(torDir, "state"))
	go func() {
		defer e.recoverLoop("bootstrap")
		var proc *tor.Process
		var err error
		for attempt := 1; attempt <= torAttempts; attempt++ {
			if attempt > 1 {
				e.torProgress(run, name, 0, Progress{Detail: fmt.Sprintf("Retrying Tor (%d/%d)", attempt, torAttempts), DetailCode: DetailTorRetry, DetailN: attempt, DetailM: torAttempts})
				os.RemoveAll(filepath.Join(torDir, "state"))
			}
			actx, acancel := context.WithTimeout(ctx, torAttemptTimeout)
			proc, err = e.startTorOnce(actx, run, torDir, bridges, name)
			acancel()
			if err == nil || ctx.Err() != nil || e.currentTor() != run {
				break
			}
			e.logWith(logrec.LevelWarn, logFields{source: logrec.SourceTor, op: "bootstrap", err: err}, "Tor attempt %d/%d failed", attempt, torAttempts)
		}
		if err == nil {
			e.mu.Lock()
			if e.torRun != run {
				e.mu.Unlock()
				proc.Stop()
				return
			}
			run.proc = proc
			e.mu.Unlock()
		} else if ctx.Err() != nil {
			err = ctx.Err()
		}

		e.mu.Lock()
		defer e.mu.Unlock()
		if e.torRun != run {
			return
		}
		if err != nil {
			e.torFailedLocked(run, err)
			return
		}
		opts := run.opts
		opts.TorSocks = run.proc.SocksAddr
		e.logWith(logrec.LevelInfo, logFields{source: logrec.SourceTor, op: "bootstrap"}, "Tor is ready")
		if err := e.startSingboxLocked(run.profiles, opts, run.profile.ID); err != nil {
			run.stop()
			e.torRun = nil
			return
		}
		run.inUse.Store(true)
		go func() {
			defer e.recoverLoop("connect")
			e.watchTor(run)
		}()
	}()
	return nil
}

// torAttempts is how many times Tor is started before giving up: snowflake
// and bridges are intermittent, and a fresh start often succeeds at once.
const (
	torAttempts       = 3
	torAttemptTimeout = 90 * time.Second
)

func (e *Engine) currentTor() *torRun {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.torRun
}

// torRingPercent is where the connection ring stands when Tor's own progress (bootstrap scaled to
// 0-100, "building a circuit" included) is percent: its slice of the ring, torPercentFrom to torPercentTo.
func torRingPercent(percent int) int {
	percent = min(max(percent, 0), 100)
	return torPercentFrom + (torPercentTo-torPercentFrom)*percent/100
}

// torProgress publishes Tor's bootstrap in the connection ring.
func (e *Engine) torProgress(run *torRun, name string, percent int, detail Progress) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.torRun != run || e.state.Status != StatusStarting {
		return
	}
	state := e.state
	detail.Stage, detail.Profile = StageEngineStart, name
	detail.Percent = torRingPercent(percent)
	if detail.DetailCode == DetailTorBootstrap {
		// Say the ring's own number, not Tor's: two different percents next to
		// each other (label 90 %, ring 54 %) looked like a bug.
		detail.DetailN = detail.Percent
		detail.Detail = fmt.Sprintf("Connecting to Tor %d%%", detail.Percent)
	}
	state.Progress = &detail
	e.setState(state)
}

// startTorOnce starts Tor and waits until it can carry a connection: its
// bootstrap finishes and a test connection through a fresh circuit works.
func (e *Engine) startTorOnce(ctx context.Context, run *torRun, dir string, bridges []string, name string) (*tor.Process, error) {
	// Snowflake and the other transports log through the standard logger; only their problems reach the app log.
	tor.SetTransportLog(func(line string) {
		e.logWith(logrec.LevelWarn, logFields{source: logrec.SourceTor, target: "transport", op: "bootstrap"}, "%s", line)
	})
	proc, err := tor.Start(tor.Config{
		DataDir:  dir,
		Bridges:  bridges,
		LogLevel: torLogLevel(),
		OnBootstrap: func(percent int, status string) {
			e.torProgress(run, name, percent*9/10, Progress{DetailCode: DetailTorBootstrap})
		},
		OnPath: func(path []tor.Hop) { e.torPath(run, path) },
		OnLog:  func(rec logrec.Record) { e.torRecord(run, rec) },
	})
	if err != nil {
		return nil, err
	}
	if err = proc.Ready(ctx); err == nil {
		e.torProgress(run, name, 92, Progress{Detail: "Building a Tor circuit", DetailCode: DetailTorCircuit})
		err = tor.CheckCircuit(ctx, proc.SocksAddr)
	}
	if err != nil {
		proc.Stop()
		return nil, err
	}
	return proc, nil
}

// torPath records the circuit Tor reports and, while the tunnel runs, shows it in the state.
func (e *Engine) torPath(run *torRun, path []tor.Hop) {
	hops := make([]TorHop, len(path))
	for i, h := range path {
		hops[i] = TorHop{Role: h.Role, Country: h.Country}
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.torRun != run {
		return
	}
	run.path = hops
	if e.state.Status == StatusRunning {
		s := e.state
		s.TorPath = hops
		e.setState(s)
	}
}

// torRecord passes on a record of omnitun-tor (it is scrubbed on the way, like every record). While Tor is still
// bootstrapping a failure is retried, so it does not notify then.
func (e *Engine) torRecord(run *torRun, rec logrec.Record) {
	if rec.Level < logrec.LevelFatal && !logrec.Enabled(rec.Level) && !rec.Notify {
		return
	}
	if rec.Notify && !run.inUse.Load() {
		rec.Notify = false
	}
	if rec.Notify {
		run.notified.Store(true)
	}
	e.deliver(rec, false)
}

// watchTor ends the tunnel when the Tor process dies while connected: nothing else would tell the user.
func (e *Engine) watchTor(run *torRun) {
	<-run.proc.Done()
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.torRun != run {
		return // stopped by the engine
	}
	cause := errors.New("the Tor client stopped")
	if !run.notified.Load() {
		e.logWith(logrec.LevelError, logFields{source: logrec.SourceTor, code: ErrTorExited, err: run.proc.Err(), notify: true},
			"the Tor client stopped on its own")
	}
	e.dropReported = true
	e.torFailedLocked(run, cause)
	e.dropReported = false
}

// torFailedLocked reports a failed Tor bootstrap or a dead Tor client,
// failing over to the next profile when enabled. e.mu must be held.
func (e *Engine) torFailedLocked(run *torRun, cause error) {
	if e.torRun == run {
		e.torRun = nil
	}
	if e.instance != nil {
		_ = e.teardownLocked()
	}
	run.stop()
	bridges, _ := torBridges(run.profile)
	reason := torErrorText(cause, len(bridges) > 0)
	msg := fmt.Sprintf("%s failed: %s", stageLabel[StageEngineStart], reason)
	e.logWith(logrec.LevelError, logFields{source: logrec.SourceTor, code: errorCode(msg), err: cause}, "%s failed", stageLabel[StageEngineStart])
	e.setState(State{Status: StatusError, Error: msg, Selected: run.profile.ID, Progress: progress(StageEngineStart, e.name(run.profile.ID))})
}
