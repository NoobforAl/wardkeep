package engine

import (
	"context"
	"fmt"
	"time"

	box "github.com/sagernet/sing-box"

	"github.com/NoobforAl/omnitun/core/logrec"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// handshake reaches a server through the tunnel before reporting
// "connected". The selected profile is tried first; with failover on, the
// remaining profiles follow in list order. If none responds, the tunnel is
// torn down and the error names the stage and whether the device is offline.
func (e *Engine) handshake(ctx context.Context, instance *box.Box, order []string, selected string, opts singbox.Options) {
	testURL := opts.TestURL
	if testURL == "" {
		testURL = "https://www.gstatic.com/generate_204"
	}
	candidates := []string{selected}
	if opts.Failover && selected != singbox.TagAuto {
		candidates = append(candidates, rotateAfter(order, selected)...)
	}

	var firstErr error
	for i, tag := range candidates {
		if !e.updateProgress(instance, progress(StageHandshake, e.nameLocked(tag))) {
			return // stopped meanwhile
		}
		// The auto group probes through the selector, which follows the urltest group.
		probeTag := tag
		if tag == singbox.TagAuto {
			probeTag = singbox.TagSelect
		}
		err := e.probe(ctx, instance, probeTag, testURL)
		if err == nil {
			e.mu.Lock()
			if e.instance != instance {
				e.mu.Unlock()
				return
			}
			if i > 0 {
				e.logWith(logrec.LevelWarn, logFields{profile: selected, err: firstErr}, "failover: the profile did not respond, using %s", tag)
				_ = e.selectLocked(tag, &FailoverEvent{From: selected, To: tag, Reason: firstErr.Error(), At: time.Now()})
			}
			s := e.state
			s.Status, s.Since, s.Error, s.Progress = StatusRunning, time.Now(), "", progress(StageConnected, e.name(tag))
			e.setState(s)
			e.mu.Unlock()
			e.logWith(logrec.LevelInfo, logFields{profile: tag}, "connected")
			if opts.Failover {
				go func() {
					defer e.recoverLoop("connect")
					e.failoverLoop(ctx, instance, order, opts)
				}()
			}
			return
		}
		if firstErr == nil {
			firstErr = err
		}
		e.logWith(logrec.LevelWarn, logFields{profile: tag, err: err}, "handshake failed")
		if ctx.Err() != nil {
			return
		}
	}

	// Nothing answered: tell "offline" apart from "servers unreachable".
	msg := fmt.Sprintf("%s failed: %s", stageLabel[StageHandshake], plainError(firstErr))
	if nerr := e.netCheck(ctx, instance); nerr != nil {
		msg = msgNoInternet
	}
	e.logWith(logrec.LevelError, logFields{code: errorCode(msg), err: firstErr}, "%s failed", stageLabel[StageHandshake])
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance != instance {
		return
	}
	failed := progress(StageHandshake, e.name(selected))
	_ = e.stopLocked()
	e.setState(State{Status: StatusError, Error: msg, Progress: failed, NoNetwork: msg == msgNoInternet})
}

// updateProgress sets the progress if instance is still running; it reports whether it was.
func (e *Engine) updateProgress(instance *box.Box, prog *Progress) bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.instance != instance {
		return false
	}
	s := e.state
	s.Progress = prog
	e.setState(s)
	return true
}
