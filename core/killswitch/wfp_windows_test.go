//go:build windows

package killswitch

import (
	"errors"
	"net/netip"
	"os"
	"testing"

	"github.com/tailscale/wf"
	"golang.org/x/sys/windows"
)

func testRules(t *testing.T) []Rule {
	t.Helper()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	rules, err := Build(Options{
		ServerAddrs: []netip.Addr{netip.MustParseAddr("203.0.113.7"), netip.MustParseAddr("2001:db8::7")},
		TunLUID:     0x6001000000000,
		Apps:        []string{exe},
		AllowLAN:    true,
		AllowRanges: []netip.Prefix{netip.MustParsePrefix("100.64.0.0/10"), netip.MustParsePrefix("2a00:1450::/32")},
	})
	if err != nil {
		t.Fatal(err)
	}
	return rules
}

// Every rule must convert to the library's types, each on the layer it
// belongs to.
func TestToWFConvertsEveryRule(t *testing.T) {
	appIDs := map[string]string{}
	layers := map[wf.LayerID]int{}
	for _, r := range testRules(t) {
		wr, err := toWF(r, appIDs)
		if err != nil {
			t.Fatalf("%s: %v", r.Name, err)
		}
		layers[wr.Layer]++
		if wr.Weight != r.Weight || wr.Name != r.Name {
			t.Errorf("%s: weight or name lost", r.Name)
		}
		wantAction := wf.ActionPermit
		if r.Action == Block {
			wantAction = wf.ActionBlock
		}
		if wr.Action != wantAction {
			t.Errorf("%s: action %v", r.Name, wr.Action)
		}
	}
	for _, l := range []wf.LayerID{wf.LayerALEAuthConnectV4, wf.LayerALEAuthConnectV6, wf.LayerALEAuthRecvAcceptV4, wf.LayerALEAuthRecvAcceptV6} {
		if layers[l] == 0 {
			t.Errorf("no rule on layer %v", l)
		}
	}
	if len(appIDs) != 1 {
		t.Errorf("application id lookups: %v", appIDs)
	}
}

// The firewall checks each condition's value type against its field when a
// rule is added. This asks it to, with rules changed to Permit and no sublayer,
// so that even an elevated run could not change anything: the call must fail,
// but only in the operating system, never because our values have the wrong
// type for their field.
func TestRulesPassTheLibrariesTypeCheck(t *testing.T) {
	sess, err := wf.New(&wf.Options{Name: namePrefix + " test", Dynamic: true})
	if err != nil {
		t.Skipf("cannot open the filtering platform: %v", err)
	}
	defer sess.Close()
	appIDs := map[string]string{}
	for _, r := range testRules(t) {
		wr, err := toWF(r, appIDs)
		if err != nil {
			t.Fatal(err)
		}
		wr.Action = wf.ActionPermit
		id, _ := windows.GenerateGUID()
		wr.ID = wf.RuleID(id)
		sub, _ := windows.GenerateGUID() // does not exist, so the add cannot succeed
		wr.Sublayer = wf.SublayerID(sub)
		err = sess.AddRule(wr)
		if err == nil {
			t.Fatalf("%s: added to a sublayer that does not exist?", r.Name)
		}
		var errno windows.Errno
		if !errors.As(err, &errno) {
			t.Errorf("%s: rejected by the library's type check, not by the system: %v", r.Name, err)
		}
	}
}

func TestToWFRejectsBadValues(t *testing.T) {
	bad := []Rule{
		{Name: "x", Direction: 0, Family: IPv4, Action: Permit},
		{Name: "x", Direction: Outbound, Family: IPv4, Action: 0},
		{Name: "x", Direction: Outbound, Family: IPv4, Action: Permit, Conditions: []Condition{{Field: Protocol, Values: []any{"tcp"}}}},
		{Name: "x", Direction: Outbound, Family: IPv4, Action: Permit, Conditions: []Condition{{Field: Application, Values: []any{7}}}},
		{Name: "x", Direction: Outbound, Family: IPv4, Action: Permit, Conditions: []Condition{{Field: 99}}},
	}
	for i, r := range bad {
		if _, err := toWF(r, map[string]string{}); err == nil {
			t.Errorf("case %d: expected an error", i)
		}
	}
}

func TestTunLUIDUnknownAdapter(t *testing.T) {
	if _, err := tunLUID("omnitun-test-no-such-adapter-4417"); err == nil {
		t.Error("expected an error for a missing adapter")
	}
}

func TestBackendRemoveWithoutApply(t *testing.T) {
	b := newBackend()
	if err := b.Remove(); err != nil {
		t.Errorf("Remove on a fresh backend: %v", err)
	}
}
