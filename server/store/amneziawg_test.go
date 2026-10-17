package store

import (
	"encoding/json"
	"maps"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/awg"
)

func num(t *testing.T, a AmneziaWG, key string) int {
	t.Helper()
	n, err := strconv.Atoi(a.Params[key])
	if err != nil {
		t.Fatalf("%s = %q", key, a.Params[key])
	}
	return n
}

// Classic (1.x) parameters follow AmneziaWG 1.x's rules for every server.
func TestNewAmneziaWGClassicParametersAreValid(t *testing.T) {
	for range 300 {
		a, err := NewAmneziaWGVersion(AWGClassic)
		if err != nil {
			t.Fatal(err)
		}
		if a.PrivateKey == "" || a.PublicKey == "" || a.PrivateKey == a.PublicKey {
			t.Fatalf("keys: %+v", a)
		}
		if len(a.Params) != 9 || a.Version() != AWGClassic || awg.Generation(a.Params) != "1.x" {
			t.Fatalf("not a 1.x parameter set: %v", a.Params)
		}
		if err := awg.CheckParams(a.Params); err != nil {
			t.Fatalf("%v: %v", a.Params, err)
		}
		jc, jmin, jmax := num(t, a, "jc"), num(t, a, "jmin"), num(t, a, "jmax")
		if jc < 1 || jc > 128 || jmin >= jmax || jmax > 1280 {
			t.Fatalf("junk parameters jc=%d jmin=%d jmax=%d", jc, jmin, jmax)
		}
		s1, s2 := num(t, a, "s1"), num(t, a, "s2")
		if s1 > 1132 || s2 > 1188 || s1+56 == s2 {
			t.Fatalf("padding s1=%d s2=%d (init and response would be the same size)", s1, s2)
		}
		seen := map[int]bool{}
		for _, k := range []string{"h1", "h2", "h3", "h4"} {
			h := num(t, a, k)
			if h <= 4 || seen[h] {
				t.Fatalf("header %s=%d is WireGuard's own or repeated", k, h)
			}
			seen[h] = true
		}
	}
}

func span(t *testing.T, a AmneziaWG, key string) (lo, hi uint64) {
	t.Helper()
	l, h, ok := strings.Cut(a.Params[key], "-")
	if !ok {
		t.Fatalf("%s = %q is not a range", key, a.Params[key])
	}
	lo, err1 := strconv.ParseUint(l, 10, 32)
	hi, err2 := strconv.ParseUint(h, 10, 32)
	if err1 != nil || err2 != nil || lo > hi {
		t.Fatalf("%s = %q", key, a.Params[key])
	}
	return lo, hi
}

// The default is AmneziaWG 2.0, and its parameters pass the client's own checks
// (awg.CheckParams, the same ones the app importer uses) in every one of many
// random draws, with the rules written out again here.
func TestNewAmneziaWG2ParametersAreValid(t *testing.T) {
	for range 2000 {
		a, err := NewAmneziaWG()
		if err != nil {
			t.Fatal(err)
		}
		if a.Version() != AWG2 || awg.Generation(a.Params) != "2.0" {
			t.Fatalf("the default is not 2.0: %v", a.Params)
		}
		if len(a.Params) != 11 {
			t.Fatalf("2.0 needs jc, jmin, jmax, s1-s4 and h1-h4: %v", a.Params)
		}
		if err := awg.CheckParams(a.Params); err != nil {
			t.Fatalf("%v: %v", a.Params, err)
		}
		jc, jmin, jmax := num(t, a, "jc"), num(t, a, "jmin"), num(t, a, "jmax")
		if jc < 4 || jc > 12 || jmin >= jmax || jmax > 1280 {
			t.Fatalf("junk parameters jc=%d jmin=%d jmax=%d", jc, jmin, jmax)
		}
		s1, s2, s3, s4 := num(t, a, "s1"), num(t, a, "s2"), num(t, a, "s3"), num(t, a, "s4")
		if s1 > 1132 || s2 > 1188 || s3 > 1216 || s4 > 1248 || s1+56 == s2 {
			t.Fatalf("padding s1=%d s2=%d s3=%d s4=%d", s1, s2, s3, s4)
		}
		var los, his [4]uint64
		for i, k := range []string{"h1", "h2", "h3", "h4"} {
			los[i], his[i] = span(t, a, k)
			if los[i] <= 4 || his[i] > 0xffffffff {
				t.Fatalf("%s = %s reaches WireGuard's own message types 1-4 or leaves uint32", k, a.Params[k])
			}
			if his[i] == los[i] {
				t.Fatalf("%s = %s is a single value, not a range", k, a.Params[k])
			}
		}
		for i := range los {
			for j := i + 1; j < len(los); j++ {
				if los[i] <= his[j] && los[j] <= his[i] {
					t.Fatalf("h%d and h%d overlap: %v", i+1, j+1, a.Params)
				}
			}
		}
	}
}

// The header ranges are not always in the same order and not always the same
// width: two servers do not look alike.
func TestAWG2HeadersVary(t *testing.T) {
	orders := map[bool]bool{}
	widths := map[uint64]bool{}
	for range 200 {
		a, _ := NewAmneziaWG()
		lo1, hi1 := span(t, a, "h1")
		lo2, _ := span(t, a, "h2")
		orders[lo1 < lo2] = true
		widths[hi1-lo1] = true
	}
	if len(orders) != 2 || len(widths) < 100 {
		t.Fatalf("the header ranges are too predictable: orders %v, %d widths", orders, len(widths))
	}
}

func TestParseAWGVersion(t *testing.T) {
	for in, want := range map[string]string{"": AWG2, "2": AWG2, "2.0": AWG2, " NEW ": AWG2, "1": AWGClassic, "1.x": AWGClassic, "Classic": AWGClassic} {
		if got, err := ParseAWGVersion(in); err != nil || got != want {
			t.Errorf("ParseAWGVersion(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"3", "1.5", "two"} {
		if _, err := ParseAWGVersion(bad); err == nil {
			t.Errorf("ParseAWGVersion(%q) was accepted", bad)
		}
	}
	if _, err := NewAmneziaWGVersion("9"); err == nil {
		t.Error("an unknown version made parameters")
	}
}

// Init follows its option: 2.0 by default, 1.x when asked, and a mistake
// creates nothing.
func TestInitChoosesTheAmneziaWGVersion(t *testing.T) {
	for opt, want := range map[string]string{"": AWG2, "2.0": AWG2, "1.x": AWGClassic, "classic": AWGClassic} {
		st, err := Init(Open(tempDir(t)), InitOptions{PublicHost: "203.0.113.7", AmneziaWGVersion: opt})
		if err != nil {
			t.Fatalf("%q: %v", opt, err)
		}
		if got := st.Server.AmneziaWG.Version(); got != want {
			t.Errorf("init with %q: AmneziaWG %s, want %s", opt, got, want)
		}
		if err := awg.CheckParams(st.Server.AmneziaWG.Params); err != nil {
			t.Errorf("init with %q: %v", opt, err)
		}
	}
	s := Open(tempDir(t))
	if _, err := Init(s, InitOptions{PublicHost: "203.0.113.7", AmneziaWGVersion: "7"}); err == nil || s.Exists() {
		t.Fatalf("a wrong version created a server (err=%v)", err)
	}
}

// A server stored by an older build (a hand-written 1.x identity without s3 and
// s4) stays exactly as it was when it is loaded, migrated and saved again.
func TestStoredClassicInterfaceIsUntouched(t *testing.T) {
	s := Open(tempDir(t))
	params := map[string]string{"jc": "5", "jmin": "50", "jmax": "90", "s1": "30", "s2": "40", "h1": "111", "h2": "222", "h3": "333", "h4": "444"}
	old := map[string]any{
		"version": 1,
		"server": map[string]any{
			"name": "Old", "public_host": "1.2.3.4", "protocols": map[string]any{},
			"amneziawg": map[string]any{"private_key": "priv", "public_key": "pub", "params": params},
		},
		"users": []any{},
	}
	data, _ := json.Marshal(old)
	if err := os.WriteFile(filepath.Join(s.Dir, "state.json"), data, 0o600); err != nil {
		t.Fatal(err)
	}
	for range 3 {
		got, err := s.Load()
		if err != nil {
			t.Fatal(err)
		}
		a := got.Server.AmneziaWG
		if !maps.Equal(a.Params, params) || a.PrivateKey != "priv" || a.PublicKey != "pub" || a.Version() != AWGClassic {
			t.Fatalf("a load changed the stored 1.x interface: %+v", a)
		}
		if err := s.Save(got); err != nil {
			t.Fatal(err)
		}
	}
}

// A new server and an old state file both end up with an AmneziaWG identity
// that stays the same across loads, and the protocol is off. A state file
// without one is a new interface, so it is AmneziaWG 2.0.
func TestAmneziaWGIdentityIsCreatedOnceAndOff(t *testing.T) {
	s := Open(tempDir(t))
	old := map[string]any{
		"version": 1,
		"server":  map[string]any{"name": "Old", "public_host": "1.2.3.4", "protocols": map[string]any{}},
		"users":   []any{},
	}
	data, _ := json.Marshal(old)
	if err := os.WriteFile(filepath.Join(s.Dir, "state.json"), data, 0o600); err != nil {
		t.Fatal(err)
	}
	st, err := s.Load()
	if err != nil {
		t.Fatal(err)
	}
	if st.Server.AmneziaWG.PrivateKey == "" || len(st.Server.AmneziaWG.Params) != 11 || st.Server.AmneziaWG.Version() != AWG2 {
		t.Fatalf("no AmneziaWG identity after migration: %+v", st.Server.AmneziaWG)
	}
	if p := st.Server.Protocols[AmneziaWGKey]; p == nil || p.Enabled || p.Port != 51821 {
		t.Fatalf("amneziawg = %+v", p)
	}
	again, err := s.Load()
	if err != nil {
		t.Fatal(err)
	}
	if again.Server.AmneziaWG.PublicKey != st.Server.AmneziaWG.PublicKey {
		t.Fatal("the identity was regenerated on the second load")
	}
}
