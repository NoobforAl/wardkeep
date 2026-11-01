package engine

import (
	"fmt"
	"strings"
	"time"

	"github.com/NoobforAl/wardkeep/core/logrec"
	"github.com/NoobforAl/wardkeep/core/profile"
	"github.com/NoobforAl/wardkeep/core/singbox"
)

// stageOrder numbers the connection stages for the log: "step 3/6: Starting engine".
var stageOrder = []string{StageNetworkCheck, StagePrepare, StageEngineStart, StageTunnelUp, StageHandshake, StageConnected}

// stageStep is the 1-based number of stage, 0 for an unknown one.
func stageStep(stage string) int {
	for i, s := range stageOrder {
		if s == stage {
			return i + 1
		}
	}
	return 0
}

// stepLog follows one connect attempt through its stages, so the log tells each step, each retry and how long
// they took. Guarded by e.mu.
type stepLog struct {
	start time.Time // zero: no attempt is being followed
	// early is set when the network check started the attempt; Start then keeps its conn id.
	early bool
	done  bool

	stage   string
	stageAt time.Time
	retry   int
	detail  string
	retries int // retries taken so far, over all steps
	taken   int // steps taken (a connect may start after the network check)

	slowest   string
	slowestIn time.Duration
}

// begin starts following an attempt.
func (s *stepLog) begin(now time.Time) { *s = stepLog{start: now} }

// endStage closes the current stage and keeps the slowest one.
func (s *stepLog) endStage(now time.Time) {
	if s.stage == "" {
		return
	}
	if took := now.Sub(s.stageAt); s.slowest == "" || took > s.slowestIn {
		s.slowest, s.slowestIn = s.stage, took
	}
}

// retryOf is which retry of its step p is (0 for the first try) and how many retries the step allows.
func retryOf(p *Progress) (retry, retries int) {
	if p.DetailCode == DetailTorRetry && p.DetailN > 0 {
		return p.DetailN - 1, p.DetailM - 1
	}
	return p.retry, p.retries
}

// logStepLocked writes a record when a connect attempt moves to another step or retries one, and a summary
// when it ends. setState calls it with every state; e.mu must be held.
func (e *Engine) logStepLocked(state State) {
	s := &e.steps
	if s.start.IsZero() || s.done {
		return
	}
	if state.Status == StatusError || state.Status == StatusStopped {
		e.finishStepsLocked(state.Status)
		return
	}
	now := time.Now()
	total := len(stageOrder)
	p := state.Progress
	if p == nil {
		return
	}
	step := stageStep(p.Stage)
	if step == 0 {
		return
	}
	retry, retries := retryOf(p)
	if p.Stage == s.stage && retry == s.retry {
		// The same step: only a finer status (Tor's bootstrap), at debug.
		if p.Detail != "" && p.Detail != s.detail {
			s.detail = p.Detail
			e.logWith(logrec.LevelDebug, logFields{op: "connect", extra: map[string]any{"step": step, "steps": total, "stage": p.Stage}},
				"step %d/%d: %s: %s", step, total, stageLabel[p.Stage], p.Detail)
		}
		return
	}
	s.endStage(now)
	if retry > 0 {
		s.retries++
	}
	if p.Stage != s.stage {
		s.taken++
	}
	s.stage, s.stageAt, s.retry, s.detail = p.Stage, now, retry, p.Detail
	if p.Stage == StageConnected {
		s.done = true
		e.logWith(logrec.LevelInfo, logFields{op: "connect", profile: state.Selected, extra: s.summary(now, step, total)},
			"connected in %s: %s, %s", roundDuration(now.Sub(s.start)), plural(s.taken, "step", "steps"), plural(s.retries, "retry", "retries"))
		return
	}
	fields := map[string]any{"step": step, "steps": total, "stage": p.Stage, "elapsed_ms": now.Sub(s.start).Milliseconds()}
	msg := fmt.Sprintf("step %d/%d: %s", step, total, stageLabel[p.Stage])
	if retry > 0 {
		fields["retry"], fields["retries"] = retry, retries
		msg += fmt.Sprintf(", retry %d/%d", retry, retries)
	}
	e.logWith(logrec.LevelInfo, logFields{op: "connect", extra: fields}, "%s", msg)
}

// finishStepsLocked writes the summary of an attempt that ended without connecting: status is StatusError
// (failed) or StatusStopped (the user stopped it). A failure that stops the tunnel before it reports the error
// calls it first, so the stop is not taken for the user's. e.mu must be held.
func (e *Engine) finishStepsLocked(status Status) {
	s := &e.steps
	if s.start.IsZero() || s.done {
		return
	}
	now := time.Now()
	s.endStage(now)
	s.done = true
	verb := "failed"
	if status == StatusStopped {
		verb = "stopped"
	}
	step, total := stageStep(s.stage), len(stageOrder)
	e.logWith(logrec.LevelInfo, logFields{op: "connect", extra: s.summary(now, step, total)},
		"connect %s at step %d/%d (%s) after %s, %s", verb, step, total, stageLabel[s.stage],
		roundDuration(now.Sub(s.start)), plural(s.retries, "retry", "retries"))
}

// summary are the fields of the record that ends an attempt.
func (s *stepLog) summary(now time.Time, step, total int) map[string]any {
	fields := map[string]any{"step": step, "steps": total, "taken": s.taken, "retries": s.retries, "elapsed_ms": now.Sub(s.start).Milliseconds()}
	if s.slowest != "" {
		fields["slowest"], fields["slowest_ms"] = s.slowest, s.slowestIn.Milliseconds()
	}
	return fields
}

// roundDuration keeps a duration short in a message: 2.8s, 140ms.
func roundDuration(d time.Duration) time.Duration {
	if d >= time.Second {
		return d.Round(100 * time.Millisecond)
	}
	return d.Round(time.Millisecond)
}

// plural is "1 retry", "2 retries".
func plural(n int, one, many string) string {
	if n == 1 {
		return "1 " + one
	}
	return fmt.Sprintf("%d %s", n, many)
}

// logBypassLocked says once per connect what goes around the VPN. Only counts are logged for the user's own
// list and apps: their entries are destinations and app names, which never go in a log (docs/logging.md §1).
// The local ranges are the same for everyone, so they are named; which of them a profile keeps inside the VPN
// is not, as that would tell the profile's private subnets. listUsed is false for a tunnel that does not
// apply the bypass list (AmneziaWG).
func (e *Engine) logBypassLocked(profiles []*profile.Profile, opts singbox.Options, listUsed bool) {
	if !logrec.Enabled(logrec.LevelInfo) {
		return
	}
	var parts []string
	fields := map[string]any{}
	if opts.ProxyPrivate {
		parts = append(parts, "local networks use the VPN")
		fields["bypass_local"] = false
	} else {
		// The ranges go in a list field: the scrubber hides every address in a message, these fixed ones too.
		names := make([]string, len(singbox.LocalPrefixes))
		for i, p := range singbox.LocalPrefixes {
			names[i] = p.String()
		}
		local := "local networks (private LANs, link-local, multicast, broadcast) skip the VPN"
		if singbox.ProfilesRouteLocal(profiles) {
			local += ", except ranges a profile routes"
		}
		parts = append(parts, local)
		fields["bypass_local"], fields["local_ranges"] = true, names
	}
	if list := opts.Bypass; !list.Empty() && !listUsed {
		parts = append(parts, "your list is not used with this protocol")
	} else if !list.Empty() {
		domains := len(list.Suffix) + len(list.Full) + len(list.Keyword) + len(list.Regex)
		what := "skip the VPN"
		if opts.BypassOnly {
			what = "are the only ones that use the VPN"
		}
		parts = append(parts, fmt.Sprintf("your list: %s and %s %s", plural(domains, "domain", "domains"),
			plural(len(list.CIDRs), "IP range", "IP ranges"), what))
		fields["bypass_domains"], fields["bypass_ranges"], fields["bypass_only"] = domains, len(list.CIDRs), opts.BypassOnly
	}
	if opts.Mode == singbox.ModeTUN {
		switch apps := withoutSelf(opts.IncludePackages); {
		case len(opts.IncludePackages) > 0:
			parts = append(parts, fmt.Sprintf("only %s use the VPN", plural(apps, "app", "apps")))
			fields["apps_included"] = apps
		case len(opts.ExcludePackages) > 0:
			apps = withoutSelf(opts.ExcludePackages)
			parts = append(parts, fmt.Sprintf("%s skip the VPN", plural(apps, "app", "apps")))
			fields["apps_excluded"] = apps
		}
	}
	e.logWith(logrec.LevelInfo, logFields{op: "connect", extra: fields}, "bypass: %s", strings.Join(parts, "; "))
}

// withoutSelf counts packages without SelfPackage (the app itself, which always stays out of its own VPN).
func withoutSelf(packages []string) int {
	n := 0
	for _, p := range packages {
		if p != singbox.SelfPackage {
			n++
		}
	}
	return n
}
