package control

import (
	"context"
	"fmt"
	"runtime"
	"sync"
	"time"

	"github.com/NoobforAl/omnitun/core/engine"
	"github.com/NoobforAl/omnitun/core/killswitch"
	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// ksState follows one connection's kill switch (core/killswitch), which the
// server arms and disarms from the engine's state changes:
//
//   - "start" with kill_switch: the request is checked, the servers' addresses
//     are resolved (before the tunnel exists, so the answer is the real one)
//     and, with kill_switch_early, the block is raised at once;
//   - connected: the block is raised (or re-raised) with the tunnel adapter
//     permitted;
//   - an error or a stop reported by the engine after having been connected (the
//     tunnel dropped, a failover or restart tears it down): the block stays,
//     that is the point of it;
//   - an error or a stop before the first connection: the block is lifted;
//   - the user's stop (the "stop" request, the lease running out, shutting the
//     server down): ksStop lifts it, whatever the engine reported.
//
// If the block cannot be raised, the tunnel is stopped and the error shown:
// a VPN that says "kill switch" and has none is worse than no VPN.
type ksState struct {
	// op serialises every change of the rules: a generation is checked and its
	// rules installed under one hold of it, and so are stop and lift. A late
	// arming therefore never runs after a stop, and a stop never lands between
	// the check and the install. Lock order: op, then mu.
	op      sync.Mutex
	mu      sync.Mutex
	gen     uint64 // changes with every start and stop; stale goroutines see it
	active  bool
	running bool // the tunnel has been up during this start
	base    killswitch.Options
}

// ksPrepare checks a start request that asks for the kill switch and, if
// asked, raises the early block. It runs before the engine starts.
func (s *Server) ksPrepare(params StartParams, opts *singbox.Options) error {
	if !params.KillSwitch {
		s.ksStop()
		return nil
	}
	fail := func(format string, a ...any) error {
		return &Error{Code: CodeStartFailed, Message: "kill switch: " + fmt.Sprintf(format, a...)}
	}
	if !s.cfg.KillSwitch.Supported() {
		return fail("%v", killswitch.ErrUnsupported)
	}
	if opts.Mode != singbox.ModeTUN {
		return fail("it needs VPN (TUN) mode")
	}
	if params.BypassOnly {
		return fail("it cannot be combined with \"only these use the VPN\"")
	}
	if err := killswitch.CheckProfiles(params.Profiles); err != nil {
		return fail("%v", err)
	}
	resolve := s.cfg.KillSwitchResolver
	if resolve == nil {
		resolve = killswitch.SystemResolver
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	servers, err := killswitch.ServerAddrs(ctx, params.Profiles, resolve)
	if err != nil {
		return fail("%v", err)
	}
	self, err := killswitch.SelfApp()
	if err != nil {
		return fail("%v", err)
	}
	base := killswitch.Options{
		ServerAddrs: servers,
		Apps:        []string{self},
		// Local networks stay out of the tunnel unless the user asked to send them through it.
		AllowLAN: !params.ProxyPrivate,
	}
	if opts.Bypass != nil {
		// Ranges the user sends around the VPN go straight out of the machine.
		base.AllowRanges = opts.Bypass.CIDRs
	}
	if err := base.Validate(); err != nil {
		return fail("%v", err)
	}
	opts.KillSwitch, opts.KillSwitchEarly = true, params.KillSwitchEarly
	if runtime.GOOS == "windows" {
		opts.TunName = singbox.WindowsTunName
	}

	s.ks.op.Lock()
	defer s.ks.op.Unlock()
	s.ks.mu.Lock()
	s.ks.gen++
	s.ks.active, s.ks.running, s.ks.base = true, false, base
	s.ks.mu.Unlock()
	if params.KillSwitchEarly {
		if err := s.cfg.KillSwitch.Arm(base, ""); err != nil {
			s.ksStopLocked()
			return fail("%v", err)
		}
		s.logf(logrec.LevelInfo, "kill switch: blocking until the tunnel is up")
	}
	return nil
}

// ksOnState reacts to an engine state. It runs with the engine's lock held, so
// it must not call the engine; anything slow goes to a goroutine.
func (s *Server) ksOnState(st engine.State) {
	s.ks.mu.Lock()
	if !s.ks.active {
		s.ks.mu.Unlock()
		return
	}
	gen := s.ks.gen
	switch st.Status {
	case engine.StatusRunning:
		s.ks.running = true
		base := s.ks.base
		s.ks.mu.Unlock()
		go s.ksRaise(gen, base)
	case engine.StatusError:
		running := s.ks.running
		s.ks.mu.Unlock()
		if !running {
			go s.ksLift(gen)
		}
	case engine.StatusStopped:
		// The engine stops itself too (a restart, a failover): after the
		// tunnel has been up that must not open the network. The user's stop
		// comes through ksStop. Before the first connection nothing is worth
		// blocking for.
		running := s.ks.running
		s.ks.mu.Unlock()
		if !running {
			go s.ksLift(gen)
		}
	default:
		s.ks.mu.Unlock()
	}
}

// ksRaise blocks everything but the tunnel, now that the tunnel exists. A
// generation that has been stopped or replaced meanwhile installs nothing and,
// above all, removes nothing: the rules belong to whoever holds the lock.
func (s *Server) ksRaise(gen uint64, base killswitch.Options) {
	s.ks.op.Lock()
	s.ks.mu.Lock()
	stale := s.ks.gen != gen || !s.ks.active
	s.ks.mu.Unlock()
	if stale {
		s.ks.op.Unlock()
		return
	}
	err := s.cfg.KillSwitch.Arm(base, singbox.WindowsTunName)
	if err == nil {
		s.ks.op.Unlock()
		s.logf(logrec.LevelInfo, "kill switch: only the tunnel (and the VPN servers) can reach the network")
		return
	}
	s.ksLiftLocked(gen)
	s.ks.op.Unlock()
	s.logf(logrec.LevelError, "kill switch: cannot raise the block, stopping the tunnel: %v", err)
	s.engine.Stop()
	s.engine.FailAt(engine.StageTunnelUp, fmt.Errorf("kill switch: %w", err))
}

// ksLift removes the block, unless a newer start has taken over.
func (s *Server) ksLift(gen uint64) {
	s.ks.op.Lock()
	defer s.ks.op.Unlock()
	s.ksLiftLocked(gen)
}

// ksLiftLocked is ksLift with s.ks.op held.
func (s *Server) ksLiftLocked(gen uint64) {
	s.ks.mu.Lock()
	if s.ks.gen != gen {
		s.ks.mu.Unlock()
		return
	}
	s.ks.active, s.ks.running = false, false
	s.ks.gen++
	s.ks.mu.Unlock()
	if err := s.cfg.KillSwitch.Disarm(); err != nil {
		s.logf(logrec.LevelError, "kill switch: cannot remove the block: %v", err)
	}
}

// ksStop removes the block whatever start it belongs to: the user's stop.
func (s *Server) ksStop() {
	if s.cfg.KillSwitch == nil {
		return
	}
	s.ks.op.Lock()
	defer s.ks.op.Unlock()
	s.ksStopLocked()
}

// ksStopLocked is ksStop with s.ks.op held.
func (s *Server) ksStopLocked() {
	s.ks.mu.Lock()
	s.ks.active, s.ks.running = false, false
	s.ks.gen++
	s.ks.mu.Unlock()
	if err := s.cfg.KillSwitch.Disarm(); err != nil {
		s.logf(logrec.LevelError, "kill switch: cannot remove the block: %v", err)
	}
}
