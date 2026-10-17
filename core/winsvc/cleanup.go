package winsvc

import (
	"errors"
	"fmt"
	"strings"
)

// What the tunnel mode leaves behind when the core dies without cleaning up
// (found by reading sing-tun's Windows code, tun_windows.go):
//
//   - a Wintun network adapter, named after the TUN inbound (WindowsTunName)
//     and identified by a GUID derived from that name. Wintun adapters are
//     real devices: they outlive the process that made them. sing-tun reuses
//     an adapter that is still there (it opens it when creating fails with
//     "exists"), but the adapter then still holds the old routes;
//   - on that adapter: its IP addresses, its routes (the VPN's default
//     routes and the exclusions) and its DNS servers. They are properties of
//     the adapter, so removing the adapter removes them; flushing them first
//     covers an adapter that cannot be removed;
//   - the resolver cache, which may still hold answers of the tunnel's DNS;
//   - firewall objects: the strict-route filters of sing-tun and our kill
//     switch live in dynamic WFP sessions, which Windows removes when the
//     process ends. Nothing to do for those, but objects with our name that
//     somebody made persistent are removed too.
//
// Not handled: the system proxy of proxy mode. It is a per-user registry
// setting that sing-box restores on a clean stop; after a crash it keeps
// pointing at a dead port. That belongs to the per-user daemon, not to a
// service that has no user.

// Step is one part of a cleanup. It reports what it did (or "" when there was
// nothing to do) and must be safe to run when nothing is left to clean.
type Step struct {
	Name string
	Run  func() (done string, err error)
}

// StepResult is the outcome of one step.
type StepResult struct {
	Name string
	Done string
	Err  error
}

// Report is the outcome of a cleanup.
type Report []StepResult

// Err joins the errors of the steps.
func (r Report) Err() error {
	var errs []error
	for _, s := range r {
		if s.Err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", s.Name, s.Err))
		}
	}
	return errors.Join(errs...)
}

// String is a one-line-per-step summary.
func (r Report) String() string {
	var b strings.Builder
	for _, s := range r {
		switch {
		case s.Err != nil:
			fmt.Fprintf(&b, "%s: FAILED: %v\n", s.Name, s.Err)
		case s.Done != "":
			fmt.Fprintf(&b, "%s: %s\n", s.Name, s.Done)
		default:
			fmt.Fprintf(&b, "%s: nothing to clean\n", s.Name)
		}
	}
	return b.String()
}

// RunCleanup runs every step, in order, even after one fails or panics.
func RunCleanup(steps []Step) Report {
	var rep Report
	for _, st := range steps {
		res := StepResult{Name: st.Name}
		func() {
			defer func() {
				if p := recover(); p != nil {
					res.Err = fmt.Errorf("panic: %v", p)
				}
			}()
			res.Done, res.Err = st.Run()
		}()
		rep = append(rep, res)
	}
	return rep
}
