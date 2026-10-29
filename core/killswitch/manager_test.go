package killswitch

import (
	"context"
	"errors"
	"net/netip"
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

type fakeBackend struct {
	applied   [][]Rule
	removed   int
	applyErr  error
	removeErr error
}

func (f *fakeBackend) Apply(r []Rule) error {
	if f.applyErr != nil {
		return f.applyErr
	}
	f.applied = append(f.applied, r)
	return nil
}

func (f *fakeBackend) Remove() error { f.removed++; return f.removeErr }

func luidOf(m map[string]uint64) func(string) (uint64, error) {
	return func(n string) (uint64, error) {
		if v, ok := m[n]; ok {
			return v, nil
		}
		return 0, errors.New("no such adapter")
	}
}

func TestManagerArmDisarm(t *testing.T) {
	b := &fakeBackend{}
	m := NewManagerWith(b, luidOf(map[string]uint64{"Wardkeep": 77}))
	if m.Armed() {
		t.Fatal("armed before Arm")
	}
	if err := m.Arm(Options{AllowLAN: true}, "Wardkeep"); err != nil {
		t.Fatal(err)
	}
	if !m.Armed() || len(b.applied) != 1 {
		t.Fatalf("armed=%v applied=%d", m.Armed(), len(b.applied))
	}
	if got := condValues(t, find(b.applied[0], IPv4, Outbound, "tunnel adapter")[0], LocalInterface); got[0] != uint64(77) {
		t.Errorf("the adapter name must become its LUID, got %v", got)
	}
	// Disarm twice: the second is a no-op.
	if err := m.Disarm(); err != nil {
		t.Fatal(err)
	}
	if err := m.Disarm(); err != nil {
		t.Fatal(err)
	}
	if m.Armed() || b.removed != 1 {
		t.Errorf("armed=%v removed=%d", m.Armed(), b.removed)
	}
}

func TestManagerArmWithoutTunnelName(t *testing.T) {
	b := &fakeBackend{}
	m := NewManagerWith(b, luidOf(nil))
	if err := m.Arm(Options{}, ""); err != nil {
		t.Fatal(err)
	}
	if len(find(b.applied[0], IPv4, Outbound, "tunnel adapter")) != 0 {
		t.Error("an empty tunnel name arms the connecting phase: no tunnel rule")
	}
}

func TestManagerUnknownAdapterDoesNotArm(t *testing.T) {
	b := &fakeBackend{}
	m := NewManagerWith(b, luidOf(nil))
	if err := m.Arm(Options{}, "Missing"); err == nil {
		t.Fatal("expected an error")
	}
	if m.Armed() || len(b.applied) != 0 {
		t.Error("nothing must be installed when the adapter is missing")
	}
}

func TestManagerFailedApplyKeepsOldState(t *testing.T) {
	b := &fakeBackend{}
	m := NewManagerWith(b, luidOf(nil))
	if err := m.Arm(Options{}, ""); err != nil {
		t.Fatal(err)
	}
	b.applyErr = errors.New("boom")
	if err := m.Arm(Options{}, ""); err == nil {
		t.Fatal("expected an error")
	}
	if !m.Armed() {
		t.Error("a failed re-arm must not report the earlier rules as gone")
	}
}

func TestManagerBuildErrorDoesNotApply(t *testing.T) {
	b := &fakeBackend{}
	m := NewManagerWith(b, luidOf(nil))
	if err := m.Arm(Options{Apps: []string{""}}, ""); err == nil || len(b.applied) != 0 {
		t.Fatal("invalid options must not reach the backend")
	}
}

func TestNilManager(t *testing.T) {
	var m *Manager
	if err := m.Arm(Options{}, ""); !errors.Is(err, ErrUnsupported) {
		t.Errorf("nil manager Arm: %v", err)
	}
	if m.Disarm() != nil || m.Armed() {
		t.Error("nil manager must be inert")
	}
}

func prof(proto, server string) *profile.Profile {
	return &profile.Profile{Name: server, Protocol: proto, Server: server, Port: 443}
}

func TestServerAddrs(t *testing.T) {
	resolve := func(_ context.Context, host string) ([]netip.Addr, error) {
		switch host {
		case "a.example":
			return []netip.Addr{netip.MustParseAddr("192.0.2.1"), netip.MustParseAddr("2001:db8::1")}, nil
		case "b.example":
			return []netip.Addr{netip.MustParseAddr("::ffff:192.0.2.1")}, nil // the same address, mapped
		}
		return nil, errors.New("nxdomain")
	}
	ovpn := prof(profile.OpenVPN, "198.51.100.1")
	ovpn.OpenVPN = &profile.OVPN{Remotes: []profile.OVPNRemote{{Server: "b.example"}, {Server: "[2001:db8::9]"}}}
	got, err := ServerAddrs(context.Background(), []*profile.Profile{
		prof(profile.VLESS, "a.example"), prof(profile.Trojan, "203.0.113.5"), ovpn, prof(profile.Trojan, "a.example"),
	}, resolve)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"192.0.2.1", "2001:db8::1", "203.0.113.5", "198.51.100.1", "2001:db8::9"}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for i, w := range want {
		if got[i].String() != w {
			t.Errorf("addr %d: %v, want %s", i, got[i], w)
		}
	}
	if _, err := ServerAddrs(context.Background(), []*profile.Profile{prof(profile.VLESS, "nope.example")}, resolve); err == nil {
		t.Error("an unresolvable server must be an error: it would be blocked")
	}
}

func TestCheckProfiles(t *testing.T) {
	if err := CheckProfiles([]*profile.Profile{prof(profile.VLESS, "a"), prof(profile.WireGuard, "b")}); err != nil {
		t.Errorf("supported protocols refused: %v", err)
	}
	for _, p := range []string{profile.Tor, profile.AmneziaWG, profile.DNSTT} {
		if err := CheckProfiles([]*profile.Profile{prof(profile.VLESS, "a"), prof(p, "x")}); err == nil {
			t.Errorf("%s must be refused", p)
		}
	}
}
