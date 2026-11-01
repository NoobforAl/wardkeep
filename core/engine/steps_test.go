package engine

import (
	"net/netip"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/wardkeep/core/logrec"
	"github.com/NoobforAl/wardkeep/core/profile"
	"github.com/NoobforAl/wardkeep/core/singbox"
)

// stepEngine is an engine logging at debug into a sink.
func stepEngine(t *testing.T) (*Engine, *recordSink) {
	t.Helper()
	t.Cleanup(logrec.ResetLevel)
	logrec.SetLevel(logrec.LevelDebug, time.Time{})
	sink := &recordSink{}
	return New(Config{DataDir: tempDir(t), OnLog: sink.add}), sink
}

func messages(records []logrec.Record) []string {
	out := make([]string, len(records))
	for i, r := range records {
		out[i] = r.Msg
	}
	return out
}

// A connect from the network check to "connected" logs each step once, a retry, and a summary, all with one conn.
func TestStepsLogEachStepAndRetry(t *testing.T) {
	e, sink := stepEngine(t)
	e.ReportProgress(StageNetworkCheck)
	e.mu.Lock()
	e.beginAttemptLocked("p_1") // Start: continues the attempt the network check began
	e.setState(State{Status: StatusStarting, Selected: "p_1", Progress: progress(StagePrepare, "")})
	e.setState(State{Status: StatusStarting, Selected: "p_1", Progress: progress(StageEngineStart, "")})
	e.setState(State{Status: StatusStarting, Selected: "p_1", Progress: progress(StageEngineStart, "")}) // no new step
	e.setState(State{Status: StatusStarting, Selected: "p_1", Progress: progress(StageTunnelUp, "")})
	first := progress(StageHandshake, "")
	first.retries = 1
	e.setState(State{Status: StatusStarting, Selected: "p_1", Progress: first})
	second := progress(StageHandshake, "")
	second.retry, second.retries = 1, 1
	e.setState(State{Status: StatusStarting, Selected: "p_1", Progress: second})
	e.setState(State{Status: StatusRunning, Selected: "p_2", Progress: progress(StageConnected, "")})
	e.setState(State{Status: StatusRunning, Selected: "p_2", Progress: progress(StageConnected, "")}) // traffic tick
	e.mu.Unlock()

	got := sink.take()
	want := []string{
		"step 1/6: Checking internet connection",
		"step 2/6: Preparing configuration",
		"step 3/6: Starting engine",
		"step 4/6: Opening tunnel",
		"step 5/6: Contacting server",
		"step 5/6: Contacting server, retry 1/1",
	}
	msgs := messages(got)
	if len(msgs) != len(want)+1 {
		t.Fatalf("records:\n%s", strings.Join(msgs, "\n"))
	}
	for i, w := range want {
		if msgs[i] != w {
			t.Errorf("record %d = %q, want %q", i, msgs[i], w)
		}
	}
	last := got[len(got)-1]
	if !strings.HasPrefix(last.Msg, "connected in ") || !strings.HasSuffix(last.Msg, ": 6 steps, 1 retry") || last.Extra["taken"] != 6 {
		t.Errorf("summary = %q", last.Msg)
	}
	if last.Profile != "p_2" || last.Extra["retries"] != 1 || last.Extra["steps"] != 6 || last.Extra["slowest"] == nil {
		t.Errorf("summary fields: profile %q, extra %v", last.Profile, last.Extra)
	}
	conn := got[0].Conn
	for _, r := range got {
		if r.Conn == "" || r.Conn != conn || r.Op != "connect" || r.Level != logrec.LevelInfo {
			t.Errorf("record %q: conn %q (want %q), op %q, level %v", r.Msg, r.Conn, conn, r.Op, r.Level)
		}
	}
	if got[5].Extra["retry"] != 1 || got[5].Extra["retries"] != 1 || got[2].Extra["step"] != 3 {
		t.Errorf("step fields: %v / %v", got[5].Extra, got[2].Extra)
	}
}

// Tor's attempts count as retries of their step; its bootstrap status shows at debug only.
func TestStepsTorRetryAndDetail(t *testing.T) {
	e, sink := stepEngine(t)
	e.mu.Lock()
	e.beginAttemptLocked("tor")
	boot := progress(StageEngineStart, "")
	boot.Detail, boot.DetailCode, boot.DetailN = "Tor 45%", DetailTorBootstrap, 45
	e.setState(State{Status: StatusStarting, Progress: boot})
	again := progress(StageEngineStart, "")
	again.Detail, again.DetailCode, again.DetailN, again.DetailM = "Retrying Tor (2/3)", DetailTorRetry, 2, 3
	e.setState(State{Status: StatusStarting, Progress: again})
	e.mu.Unlock()

	got := sink.take()
	msgs := messages(got)
	want := []string{"step 3/6: Starting engine", "step 3/6: Starting engine, retry 1/2"}
	if len(msgs) != 2 || msgs[0] != want[0] || msgs[1] != want[1] {
		t.Fatalf("records = %q, want %q", msgs, want)
	}

	// Within the same try, a new bootstrap status is a debug record.
	e.mu.Lock()
	more := *again
	more.Detail = "Tor 80%"
	e.setState(State{Status: StatusStarting, Progress: &more})
	e.mu.Unlock()
	got = sink.take()
	if len(got) != 1 || got[0].Level != logrec.LevelDebug || got[0].Msg != "step 3/6: Starting engine: Tor 80%" {
		t.Fatalf("detail record = %+v", got)
	}
}

// A failure is summarised as failed, also when the tunnel is stopped before the error is reported; a stop by
// the user mid-connect as stopped.
func TestStepsFailureAndStopSummaries(t *testing.T) {
	e, sink := stepEngine(t)
	e.mu.Lock()
	e.beginAttemptLocked("p_1")
	e.setState(State{Status: StatusStarting, Progress: progress(StageHandshake, "")})
	e.finishStepsLocked(StatusError)                   // the handshake's failure, before its stop
	e.setState(State{Status: StatusStopped})           // that stop
	e.setState(State{Status: StatusError, Error: "x"}) // and its error
	e.mu.Unlock()
	got := messages(sink.take())
	if len(got) != 2 || !strings.HasPrefix(got[1], "connect failed at step 5/6 (Contacting server) after ") || !strings.HasSuffix(got[1], ", 0 retries") {
		t.Fatalf("records = %q", got)
	}

	e.mu.Lock()
	e.beginAttemptLocked("p_1")
	e.setState(State{Status: StatusStarting, Progress: progress(StagePrepare, "")})
	e.setState(State{Status: StatusStopped})
	e.mu.Unlock()
	got = messages(sink.take())
	if len(got) != 2 || !strings.HasPrefix(got[1], "connect stopped at step 2/6 (Preparing configuration)") {
		t.Fatalf("records = %q", got)
	}
}

// A failed network check ends its attempt; the next connect gets a new conn id.
func TestStepsNetworkCheckFailureStartsFresh(t *testing.T) {
	e, sink := stepEngine(t)
	e.ReportProgress(StageNetworkCheck)
	e.FailAt(StageNetworkCheck, errOffline)
	first := sink.take()
	if len(first) != 2 || !strings.HasPrefix(first[1].Msg, "connect failed at step 1/6") {
		t.Fatalf("records = %q", messages(first))
	}
	e.mu.Lock()
	e.beginAttemptLocked("p_1")
	e.setState(State{Status: StatusStarting, Progress: progress(StagePrepare, "")})
	e.mu.Unlock()
	second := sink.take()
	if len(second) != 1 || second[0].Conn == first[0].Conn {
		t.Fatalf("second attempt reused conn %q: %+v", first[0].Conn, second)
	}
}

type offlineError struct{}

func (offlineError) Error() string { return "no network" }

var errOffline error = offlineError{}

// The bypass record counts the user's list and apps and names only the fixed local ranges.
func TestBypassRecordCountsOnly(t *testing.T) {
	e, sink := stepEngine(t)
	list := &singbox.BypassList{
		Suffix: []string{"secret-bank.example"},
		Full:   []string{"intranet.example"},
		CIDRs:  []netip.Prefix{netip.MustParsePrefix("203.0.113.0/24")},
	}
	wg := &profile.Profile{Protocol: profile.WireGuard, WireGuard: &profile.WG{AllowedIPs: []string{"0.0.0.0/0", "10.77.0.0/16"}}}
	opts := singbox.Options{Mode: singbox.ModeTUN, Bypass: list, ExcludePackages: []string{singbox.SelfPackage, "com.bank.app", "com.chat.app"}}
	e.mu.Lock()
	e.logBypassLocked([]*profile.Profile{wg}, opts, true)
	e.logBypassLocked(nil, singbox.Options{ProxyPrivate: true, Bypass: list}, false)
	e.mu.Unlock()

	got := sink.take()
	if len(got) != 2 {
		t.Fatalf("records = %q", messages(got))
	}
	msg := got[0].Msg
	for _, want := range []string{"private LANs", "except ranges a profile routes", "2 domains and 1 IP range skip the VPN", "2 apps skip the VPN"} {
		if !strings.Contains(msg, want) {
			t.Errorf("bypass record %q lacks %q", msg, want)
		}
	}
	// The fixed ranges are named in a field (a message would have them scrubbed).
	ranges, _ := got[0].Extra["local_ranges"].([]string)
	if strings.Join(ranges, " ") != "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32 fc00::/7 fe80::/10 ff00::/8" {
		t.Errorf("local_ranges = %v", got[0].Extra["local_ranges"])
	}
	if strings.Contains(strings.Join(ranges, " "), "10.77") {
		t.Errorf("local_ranges tells a profile's subnet: %v", ranges)
	}
	for _, secret := range []string{"secret-bank", "intranet", "203.0.113", "10.77", "com.bank", "com.chat"} {
		if strings.Contains(msg, secret) || strings.Contains(strings.Join(fieldValues(got[0]), " "), secret) {
			t.Errorf("bypass record names %q: %q %v", secret, msg, got[0].Extra)
		}
	}
	if got[0].Extra["bypass_domains"] != 2 || got[0].Extra["bypass_ranges"] != 1 || got[0].Extra["apps_excluded"] != 2 {
		t.Errorf("fields = %v", got[0].Extra)
	}
	if want := "bypass: local networks use the VPN; your list is not used with this protocol"; got[1].Msg != want {
		t.Errorf("AmneziaWG record = %q, want %q", got[1].Msg, want)
	}

	// Only the app itself excluded (it always is): no app count.
	e.mu.Lock()
	e.logBypassLocked(nil, singbox.Options{Mode: singbox.ModeTUN, ExcludePackages: []string{singbox.SelfPackage}}, true)
	e.mu.Unlock()
	if only := sink.take(); len(only) != 1 || strings.Contains(only[0].Msg, "app") || only[0].Extra["apps_excluded"] != nil {
		t.Errorf("self-only record = %+v", only)
	}
}

func fieldValues(r logrec.Record) []string {
	var out []string
	for k, v := range r.Extra {
		out = append(out, k)
		if s, ok := v.(string); ok {
			out = append(out, s)
		}
	}
	return out
}
