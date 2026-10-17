package control

import (
	"context"
	"errors"
	"net/netip"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/engine"
	"github.com/NoobforAl/omnitun/core/killswitch"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

type ksBackend struct {
	mu      sync.Mutex
	applied [][]killswitch.Rule
	removed int
	failOn  int    // fail the Nth Apply (1-based); 0 never
	hold    func() // called inside Apply, once, to force an interleaving
}

func (b *ksBackend) Apply(r []killswitch.Rule) error {
	if h := b.hold; h != nil {
		b.hold = nil
		h()
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.failOn == len(b.applied)+1 {
		return errors.New("access denied")
	}
	b.applied = append(b.applied, r)
	return nil
}

func (b *ksBackend) Remove() error { b.mu.Lock(); b.removed++; b.mu.Unlock(); return nil }

func (b *ksBackend) counts() (applied, removed int) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.applied), b.removed
}

func (b *ksBackend) hasTunnelRule(i int) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, r := range b.applied[i] {
		if strings.Contains(r.Name, "tunnel adapter") {
			return true
		}
	}
	return false
}

func ksServer(t *testing.T, b *ksBackend) *Server {
	t.Helper()
	m := killswitch.NewManagerWith(b, func(name string) (uint64, error) {
		if name != singbox.WindowsTunName {
			return 0, errors.New("unexpected adapter " + name)
		}
		return 99, nil
	})
	s, _ := newTestServer(t, ServerConfig{
		KillSwitch: m,
		KillSwitchResolver: func(_ context.Context, host string) ([]netip.Addr, error) {
			if host == "vpn.example" {
				return []netip.Addr{netip.MustParseAddr("203.0.113.9")}, nil
			}
			return nil, errors.New("no such host")
		},
	})
	return s
}

func ksParams(server string) StartParams {
	return StartParams{
		Mode:       "tun",
		KillSwitch: true,
		Profiles:   []*profile.Profile{{Name: "t", Protocol: profile.Trojan, Server: server, Port: 443, Password: "x"}},
	}
}

func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()
	for range 200 {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func TestKillSwitchPreflightRefusals(t *testing.T) {
	s := ksServer(t, &ksBackend{})
	tun := func(p StartParams) (StartParams, *singbox.Options) {
		return p, &singbox.Options{Mode: singbox.Mode(p.Mode)}
	}
	cases := map[string]func(*StartParams){
		"proxy mode":  func(p *StartParams) { p.Mode = "proxy" },
		"bypass only": func(p *StartParams) { p.BypassOnly = true },
		"tor": func(p *StartParams) {
			p.Profiles = append(p.Profiles, &profile.Profile{Name: "tor", Protocol: profile.Tor, Tor: &profile.TorOpts{}})
		},
		"unknown dns": func(p *StartParams) { p.Profiles[0].Server = "nowhere.example" },
	}
	for name, mutate := range cases {
		p := ksParams("vpn.example")
		mutate(&p)
		p, opts := tun(p)
		err := s.ksPrepare(p, opts)
		var ce *Error
		if !errors.As(err, &ce) || ce.Code != CodeStartFailed || !strings.Contains(ce.Message, "kill switch") {
			t.Errorf("%s: err = %v, want a START_FAILED kill switch error", name, err)
		}
	}
}

func TestKillSwitchRefusedWithoutAManager(t *testing.T) {
	s, _ := newTestServer(t, ServerConfig{})
	p := ksParams("203.0.113.1")
	err := s.ksPrepare(p, &singbox.Options{Mode: singbox.ModeTUN})
	if err == nil || !strings.Contains(err.Error(), "kill switch") {
		t.Fatalf("err = %v", err)
	}
}

func TestKillSwitchOffByDefault(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	p := ksParams("vpn.example")
	p.KillSwitch = false
	opts := &singbox.Options{Mode: singbox.ModeTUN}
	if err := s.ksPrepare(p, opts); err != nil {
		t.Fatal(err)
	}
	if opts.KillSwitch || opts.TunName != "" {
		t.Errorf("options changed without a kill switch: %+v", opts)
	}
	s.ksOnState(engine.State{Status: engine.StatusRunning})
	if a, _ := b.counts(); a != 0 {
		t.Error("the kill switch must stay off unless asked for")
	}
}

func TestKillSwitchLifecycle(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	p := ksParams("vpn.example")
	opts := &singbox.Options{Mode: singbox.ModeTUN}
	if err := s.ksPrepare(p, opts); err != nil {
		t.Fatal(err)
	}
	if !opts.KillSwitch {
		t.Error("opts.KillSwitch not set")
	}
	if a, _ := b.counts(); a != 0 {
		t.Fatal("without kill_switch_early nothing is blocked while connecting")
	}
	s.ksOnState(engine.State{Status: engine.StatusStarting})
	if a, _ := b.counts(); a != 0 {
		t.Fatal("connecting must not arm")
	}

	s.ksOnState(engine.State{Status: engine.StatusRunning})
	waitFor(t, "arming", func() bool { a, _ := b.counts(); return a == 1 })
	if !b.hasTunnelRule(0) {
		t.Error("connected: the tunnel adapter must be permitted")
	}
	servers := false
	for _, r := range b.applied[0] {
		if strings.Contains(r.Name, "VPN servers") && r.Family == killswitch.IPv4 {
			servers = r.Conditions[0].Values[0] == netip.MustParsePrefix("203.0.113.9/32")
		}
	}
	if !servers {
		t.Error("the resolved server address must be permitted")
	}

	// The tunnel drops: the block stays.
	s.ksOnState(engine.State{Status: engine.StatusError, Error: "lost"})
	s.ksOnState(engine.State{Status: engine.StatusStarting})
	if _, r := b.counts(); r != 0 {
		t.Fatal("an error after being connected must keep the block")
	}

	// Back up: re-armed, no gap.
	s.ksOnState(engine.State{Status: engine.StatusRunning})
	waitFor(t, "re-arming", func() bool { a, _ := b.counts(); return a == 2 })

	// The engine stops itself (a restart, a failover): the block stays.
	s.ksOnState(engine.State{Status: engine.StatusStopped})
	time.Sleep(50 * time.Millisecond)
	if _, r := b.counts(); r != 0 {
		t.Fatalf("an internal stop must keep the block, removed = %d", r)
	}
	if !s.cfg.KillSwitch.Armed() {
		t.Fatal("not armed after an internal stop")
	}

	// The user disconnects: the control "stop" request lifts it.
	if _, err := s.Call("stop", nil); err != nil {
		t.Fatal(err)
	}
	if _, r := b.counts(); r != 1 || s.cfg.KillSwitch.Armed() {
		t.Errorf("removed = %d, armed = %v after the user's stop", r, s.cfg.KillSwitch.Armed())
	}
	// Later states change nothing.
	s.ksOnState(engine.State{Status: engine.StatusRunning})
	time.Sleep(50 * time.Millisecond)
	if a, _ := b.counts(); a != 2 {
		t.Error("a stopped kill switch must not re-arm by itself")
	}
}

// The engine reports "stopped" without ever having been connected (a failed
// start): nothing is worth blocking for.
func TestKillSwitchStoppedBeforeConnectedLiftsTheBlock(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	p := ksParams("vpn.example")
	p.KillSwitchEarly = true
	if err := s.ksPrepare(p, &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	s.ksOnState(engine.State{Status: engine.StatusStopped})
	waitFor(t, "the block to be lifted", func() bool { _, r := b.counts(); return r == 1 })
}

// The lease running out is a user-side stop, also when the engine had already stopped itself.
func TestKillSwitchLiftedWhenTheUIIsGone(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	if err := s.ksPrepare(ksParams("vpn.example"), &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	s.ksOnState(engine.State{Status: engine.StatusRunning})
	waitFor(t, "arming", func() bool { a, _ := b.counts(); return a == 1 })
	s.ksOnState(engine.State{Status: engine.StatusStopped}) // internal
	s.cfg.Grace = 10 * time.Millisecond
	c := &client{conn: nil, send: make(chan any, 1), done: make(chan struct{})}
	s.mu.Lock()
	s.clients[c] = struct{}{}
	s.mu.Unlock()
	s.removeClient(c) // the last UI leaves
	waitFor(t, "the block to be lifted", func() bool { _, r := b.counts(); return r == 1 })
}

func TestKillSwitchEarlyBlocksWhileConnecting(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	p := ksParams("vpn.example")
	p.KillSwitchEarly = true
	if err := s.ksPrepare(p, &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	if a, _ := b.counts(); a != 1 || b.hasTunnelRule(0) {
		t.Fatal("early: one block raised at once, without a tunnel rule")
	}
	// The first connection fails: the user is not locked out.
	s.ksOnState(engine.State{Status: engine.StatusError, Error: "no route"})
	waitFor(t, "a failed first connection to lift the block", func() bool { _, r := b.counts(); return r == 1 })
}

func TestKillSwitchStopWhileConnectingLiftsTheBlock(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	p := ksParams("vpn.example")
	p.KillSwitchEarly = true
	if err := s.ksPrepare(p, &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	s.ksStop()
	if _, r := b.counts(); r != 1 {
		t.Errorf("removed = %d, want 1", r)
	}
}

func TestKillSwitchFailsClosedWhenItCannotBeRaised(t *testing.T) {
	b := &ksBackend{failOn: 1}
	s := ksServer(t, b)
	if err := s.ksPrepare(ksParams("vpn.example"), &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	s.ksOnState(engine.State{Status: engine.StatusRunning})
	waitFor(t, "the error state", func() bool {
		st := s.Engine().State()
		return st.Status == engine.StatusError && strings.Contains(st.Error, "kill switch")
	})
}

func TestKillSwitchEarlyFailureRefusesTheStart(t *testing.T) {
	b := &ksBackend{failOn: 1}
	s := ksServer(t, b)
	p := ksParams("vpn.example")
	p.KillSwitchEarly = true
	err := s.ksPrepare(p, &singbox.Options{Mode: singbox.ModeTUN})
	if err == nil || !strings.Contains(err.Error(), "access denied") {
		t.Fatalf("err = %v", err)
	}
	// A following start works and is not confused by the failed one.
	b.failOn = 0
	if err := s.ksPrepare(ksParams("vpn.example"), &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
}

// A stale arming (its generation was replaced) installs nothing and removes
// nothing, in particular not what the newer generation installed.
func TestKillSwitchStaleArmingTouchesNothing(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	if err := s.ksPrepare(ksParams("vpn.example"), &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	s.ks.mu.Lock()
	oldGen, oldBase := s.ks.gen, s.ks.base
	s.ks.mu.Unlock()
	// A newer start raises its early block first.
	p := ksParams("vpn.example")
	p.KillSwitchEarly = true
	if err := s.ksPrepare(p, &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	s.ksRaise(oldGen, oldBase)
	if a, r := b.counts(); a != 1 || r != 0 || !s.cfg.KillSwitch.Armed() {
		t.Errorf("applied = %d, removed = %d, armed = %v: the stale arming must leave the newer rules alone", a, r, s.cfg.KillSwitch.Armed())
	}
}

// A stop that arrives while the arming is inside the firewall call waits for
// it and then removes what it installed (it is not missed, and the arming is not
// left behind).
func TestKillSwitchStopDuringArmingIsNotMissed(t *testing.T) {
	b := &ksBackend{}
	s := ksServer(t, b)
	if err := s.ksPrepare(ksParams("vpn.example"), &singbox.Options{Mode: singbox.ModeTUN}); err != nil {
		t.Fatal(err)
	}
	entered, release := make(chan struct{}), make(chan struct{})
	b.hold = func() { close(entered); <-release }
	s.ks.mu.Lock()
	gen, base := s.ks.gen, s.ks.base
	s.ks.mu.Unlock()

	raised := make(chan struct{})
	go func() { s.ksRaise(gen, base); close(raised) }()
	<-entered // the arming is now inside Apply, holding the lock
	stopped := make(chan struct{})
	go func() { s.ksStop(); close(stopped) }()
	select {
	case <-stopped:
		t.Fatal("the stop ran in the middle of the arming")
	case <-time.After(100 * time.Millisecond):
	}
	close(release)
	<-raised
	<-stopped
	if a, r := b.counts(); a != 1 || r != 1 || s.cfg.KillSwitch.Armed() {
		t.Errorf("applied = %d, removed = %d, armed = %v: the stop must win", a, r, s.cfg.KillSwitch.Armed())
	}
}
