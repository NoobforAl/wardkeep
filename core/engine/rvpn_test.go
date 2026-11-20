package engine

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/NoobforAl/wardkeep/core/importer"
	"github.com/NoobforAl/wardkeep/core/profile"
	"github.com/NoobforAl/wardkeep/core/rvpn"
	"github.com/NoobforAl/wardkeep/core/singbox"
)

const rvpnTestLink = "rvpn://k3j9q2xw7a.example.org:443/api/v1/q7w2e9r4t1y6u3i8?v=1" +
	"&ik=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE" +
	"&ixk=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI" +
	"&ixs=AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw" +
	"&spk=BAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ" +
	"&pks=BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQ" +
	"&ikv=1#zz-rvpn"

// A helper-run profile (DNS tunnel, rVPN) stays in the tunnel only while its helper runs.
func TestWithoutHelpers(t *testing.T) {
	r := &profile.Profile{ID: "r", Protocol: profile.RVPN}
	d := &profile.Profile{ID: "d", Protocol: profile.DNSTT}
	v := &profile.Profile{ID: "v", Protocol: profile.VLESS}
	got := withoutHelpers([]*profile.Profile{r, d, v}, map[string]singbox.HelperSocks{"r": {Addr: "127.0.0.1:1"}})
	if len(got) != 2 || got[0] != r || got[1] != v {
		t.Fatalf("got %v", got)
	}
	if got := withoutHelpers([]*profile.Profile{r, d, v}, nil); len(got) != 1 || got[0] != v {
		t.Fatalf("without helpers: %v", got)
	}
}

// The helper's failures and the engine's own rVPN sentences come back as their codes, so the app can word them.
func TestRVPNErrorCodes(t *testing.T) {
	cases := map[string]string{
		(&rvpn.HelperError{Code: rvpn.CodeHandshake, Message: "identity mismatch"}).Error(): ErrRVPNHandshake,
		(&rvpn.HelperError{Code: rvpn.CodeUpgrade, Message: "HTTP 200"}).Error():            ErrRVPNUpgrade,
		"Preparing failed: " + rvpn.ErrMissing.Error():                                      ErrRVPNMissing,
		msgRVPNExited:     ErrRVPNExited,
		msgRVPNDesktopTUN: ErrRVPNDesktopTUN,
		(&rvpn.HelperError{Code: rvpn.CodeTLS, Message: "certificate has expired"}).Error(): ErrCertDate,
	}
	for msg, want := range cases {
		if got := errorCode(msg); got != want {
			t.Errorf("errorCode(%q) = %q, want %q", msg, got, want)
		}
	}
}

// In a desktop TUN the helper's own connections would enter the tunnel, so rVPN is refused there, before anything
// starts.
func TestRVPNRefusedInDesktopTUN(t *testing.T) {
	p, err := importer.ParseLink(rvpnTestLink)
	if err != nil {
		t.Fatal(err)
	}
	var last State
	e := New(Config{DataDir: tempDir(t), OnState: func(s State) { last = s }})
	err = e.Start([]*profile.Profile{p}, singbox.Options{Mode: singbox.ModeTUN, Selected: p.ID})
	if err == nil || !strings.Contains(err.Error(), "proxy mode") {
		t.Fatalf("err = %v", err)
	}
	if last.Status != StatusError || last.ErrorCode != ErrRVPNDesktopTUN {
		t.Fatalf("state = %+v", last)
	}
}

// A profile ID never leaves the rVPN folder, whatever it holds, and each profile keeps its own folder.
func TestRVPNDataDirStaysInside(t *testing.T) {
	base := filepath.Join("data", "rvpn") + string(filepath.Separator)
	seen := map[string]bool{}
	for _, id := range []string{"c2a0b199ce0e", "../../etc", `..\..\x`, "/abs", "", "a/b"} {
		dir := rvpnDataDir("data", id)
		if !strings.HasPrefix(dir, base) || strings.ContainsAny(strings.TrimPrefix(dir, base), `/\.`) {
			t.Errorf("id %q -> %q", id, dir)
		}
		if seen[dir] {
			t.Errorf("id %q shares %q", id, dir)
		}
		seen[dir] = true
	}
}

// Without the helper installed, the failure says so.
func TestRVPNMissingHelper(t *testing.T) {
	p, err := importer.ParseLink(rvpnTestLink)
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("WARDKEEP_RVPN_BIN", "")
	t.Setenv("PATH", "")
	var last State
	e := New(Config{DataDir: tempDir(t), OnState: func(s State) { last = s }})
	if err := e.Start([]*profile.Profile{p}, singbox.Options{Mode: singbox.ModeProxy, Selected: p.ID}); err == nil {
		t.Skip("a wardkeep-rvpn sits next to the test binary")
	}
	if last.ErrorCode != ErrRVPNMissing {
		t.Fatalf("state = %+v", last)
	}
}
