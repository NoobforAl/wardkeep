// Package rvpn runs the rVPN helper for Wardkeep: the Rust `wardkeep-rvpn` binary from rvpn/, which does rVPN's
// X3DH handshake and Double Ratchet over a WebSocket and serves the tunnel as a local SOCKS5 port. The contract
// (arguments, stdout events, stdin as the lifeline) is the header of rvpn/src/main.rs.
package rvpn

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NoobforAl/wardkeep/core/logrec"
	"github.com/NoobforAl/wardkeep/core/profile"
)

// ErrMissing is returned when the helper executable cannot be found.
var ErrMissing = errors.New("the rVPN client (wardkeep-rvpn) is not installed")

// Error codes the helper reports in its "error" event.
const (
	CodeHandshake = "handshake" // the server refused the handshake, or its identity does not match the bundle
	CodeTLS       = "tls"       // certificate or TLS failure
	CodeUpgrade   = "upgrade"   // the server did not upgrade to a WebSocket (wrong path: the decoy page)
	CodeNetwork   = "network"   // name lookup, TCP or timeout
	CodeArgs      = "args"      // the core started it wrongly
)

// HelperError is a connect failure the helper reported, with its code.
type HelperError struct{ Code, Message string }

// Error words the failure by its code; the sentences are the ones engine/errors.go turns back into codes. A TLS or
// network failure keeps the helper's message, which says what (a certificate, a timeout) in the words the
// engine's general error kinds look for.
func (e *HelperError) Error() string {
	switch e.Code {
	case CodeHandshake:
		return "the rVPN server rejected the handshake: " + e.Message
	case CodeUpgrade:
		return "the rVPN server did not open the tunnel: " + e.Message
	}
	return "rVPN: " + e.Message
}

// Config starts the helper.
type Config struct {
	// Bin is the wardkeep-rvpn executable; empty uses FindBinary.
	Bin string
	// DataDir holds the client's identity key (made there the first time) and the bundle file. One per profile:
	// the server knows a client by its key, so two profiles must not share one by accident.
	DataDir string
	// Profile is the rVPN profile to connect.
	Profile *profile.Profile
	// OnLog receives the helper's log records, and anything it writes to stderr as errors.
	OnLog func(logrec.Record)
	// LogLevel is passed as --log-level; empty keeps the helper's default.
	LogLevel string
}

// Process is a running helper.
type Process struct {
	// SocksAddr is the local SOCKS5 address (127.0.0.1:port), and Username/Password its login: random per run, so
	// no other program on the device can use the tunnel through the port.
	SocksAddr, Username, Password string

	cmd   *exec.Cmd
	stdin io.WriteCloser
	ready chan error
	done  chan struct{}
	once  sync.Once
	err   error

	mu        sync.Mutex
	lastErr   *HelperError
	connected bool
}

type event struct {
	Event   string `json:"event"`
	Socks   string `json:"socks"`
	Host    int    `json:"host"`
	Code    string `json:"code"`
	Message string `json:"message"`
}

// FindBinary locates wardkeep-rvpn: $WARDKEEP_RVPN_BIN, then next to the running executable, then $PATH.
func FindBinary() (string, error) {
	if p := os.Getenv("WARDKEEP_RVPN_BIN"); p != "" {
		return p, nil
	}
	name := "wardkeep-rvpn"
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	if exe, err := os.Executable(); err == nil {
		p := filepath.Join(filepath.Dir(exe), name)
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	if p, err := exec.LookPath(name); err == nil {
		return p, nil
	}
	return "", ErrMissing
}

// Args builds the helper's command line, and writes the bundle file it reads. Other local users can read a
// command line, so it holds nothing secret: the server address and path, and the bundle's file name (public key
// material). The SOCKS login goes in the environment (Env), which only the same user can read, and the client's own
// key stays in DataDir.
func Args(cfg Config) ([]string, error) {
	p := cfg.Profile
	if p == nil || p.RVPN == nil {
		return nil, errors.New("the profile has no rVPN settings")
	}
	if err := p.Validate(); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(cfg.DataDir, 0o700); err != nil {
		return nil, err
	}
	bundle, err := p.RVPN.Bundle.FileJSON()
	if err != nil {
		return nil, err
	}
	bundlePath := filepath.Join(cfg.DataDir, "prekey-bundle.json")
	if err := os.WriteFile(bundlePath, bundle, 0o600); err != nil {
		return nil, err
	}
	server := "wss://" + net.JoinHostPort(p.Server, strconv.Itoa(p.Port)) + p.RVPN.Path
	args := []string{"--data", cfg.DataDir, "--bundle", bundlePath, "--server", server, "--socks-port", "0"}
	for _, h := range p.RVPN.Alt {
		args = append(args, "--alt", h)
	}
	if cfg.LogLevel != "" {
		args = append(args, "--log-level", cfg.LogLevel)
	}
	return args, nil
}

// Env is the helper's environment: this process's own, without any login an earlier run left in it, plus the
// SOCKS login of this run.
func Env(user, pass string) []string {
	env := make([]string, 0, len(os.Environ())+2)
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, envSocksUser+"=") && !strings.HasPrefix(kv, envSocksPass+"=") {
			env = append(env, kv)
		}
	}
	return append(env, envSocksUser+"="+user, envSocksPass+"="+pass)
}

// The environment variables the helper reads its SOCKS login from.
const (
	envSocksUser = "WARDKEEP_RVPN_SOCKS_USER"
	envSocksPass = "WARDKEEP_RVPN_SOCKS_PASS" //nolint:gosec // G101: the name of an environment variable, not a password
)

func randomToken() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// Start launches the helper and returns once its SOCKS port listens. The tunnel itself connects on the first
// connection through the port (and again after it drops); Connected and LastError say how that went.
func Start(cfg Config) (*Process, error) {
	bin := cfg.Bin
	if bin == "" {
		var err error
		if bin, err = FindBinary(); err != nil {
			return nil, err
		}
	}
	user, err := randomToken()
	if err != nil {
		return nil, err
	}
	pass, err := randomToken()
	if err != nil {
		return nil, err
	}
	args, err := Args(cfg)
	if err != nil {
		return nil, err
	}
	proc := &Process{Username: user, Password: pass, ready: make(chan error, 1), done: make(chan struct{})}
	proc.cmd = exec.Command(bin, args...) //nolint:gosec,noctx // G204: the bundled helper with arguments built here; Stop ends it
	proc.cmd.Env = Env(user, pass)
	hideWindow(proc.cmd)
	stdout, err := proc.cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	// Closing stdin tells wardkeep-rvpn to exit (also when this process dies).
	if proc.stdin, err = proc.cmd.StdinPipe(); err != nil {
		return nil, err
	}
	stderr, _ := proc.cmd.StderrPipe()
	if err := proc.cmd.Start(); err != nil {
		return nil, fmt.Errorf("start rVPN: %w", err)
	}

	listening := make(chan string, 1)
	go func() {
		// A panic in a handler must not leave the helper blocked on a full pipe: the rest is drained unread.
		defer func() { _, _ = io.Copy(io.Discard, stdout) }()
		defer logrec.Recover(logrec.SourceRVPN, "run", cfg.OnLog)
		sc := bufio.NewScanner(stdout)
		for sc.Scan() {
			var ev event
			if json.Unmarshal(sc.Bytes(), &ev) != nil {
				continue
			}
			switch ev.Event {
			case "log":
				if cfg.OnLog != nil {
					if rec, ok := parseLogEvent(sc.Bytes()); ok {
						cfg.OnLog(rec)
					}
				}
			case "listening":
				select {
				case listening <- ev.Socks:
				default:
				}
			case "ready":
				proc.mu.Lock()
				proc.connected, proc.lastErr = true, nil
				proc.mu.Unlock()
				proc.signal(nil)
			case "error":
				he := &HelperError{Code: ev.Code, Message: ev.Message}
				proc.mu.Lock()
				proc.connected, proc.lastErr = false, he
				proc.mu.Unlock()
				proc.signal(he)
			}
		}
	}()
	if stderr != nil {
		go func() {
			defer func() { _, _ = io.Copy(io.Discard, stderr) }()
			defer logrec.Recover(logrec.SourceRVPN, "run", cfg.OnLog)
			sc := bufio.NewScanner(stderr)
			for sc.Scan() {
				if cfg.OnLog != nil && strings.TrimSpace(sc.Text()) != "" {
					cfg.OnLog(logrec.Record{Time: time.Now(), Level: logrec.LevelError, Source: logrec.SourceRVPN,
						Msg: logrec.Scrub(strings.TrimSpace(sc.Text()))})
				}
			}
		}()
	}
	go func() {
		err := proc.cmd.Wait()
		proc.err = err
		proc.signal(fmt.Errorf("the rVPN client exited: %v", err))
		close(proc.done)
	}()

	select {
	case addr := <-listening:
		proc.SocksAddr = addr
		return proc, nil
	case <-proc.done:
		return nil, fmt.Errorf("the rVPN client exited at start: %v", proc.err)
	}
}

// signal reports the first outcome of a connect attempt to Ready; later ones only update the state.
func (p *Process) signal(err error) {
	select {
	case p.ready <- err:
	default:
	}
}

// Ready waits for the outcome of the first connect attempt: nil when the handshake worked, the helper's error
// when every host failed.
func (p *Process) Ready(ctx context.Context) error {
	select {
	case err := <-p.ready:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Connected reports whether the last connect attempt worked, and LastError why it did not.
func (p *Process) Connected() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.connected
}

// LastError is the helper's last connect failure, nil after a success.
func (p *Process) LastError() *HelperError {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.lastErr
}

// parseLogEvent reads a stdout line {"event":"log", <record keys>} into a record.
func parseLogEvent(line []byte) (logrec.Record, bool) {
	var rec logrec.Record
	if json.Unmarshal(line, &rec) != nil {
		return rec, false
	}
	delete(rec.Extra, "event")
	if rec.Source == "" {
		rec.Source = logrec.SourceRVPN
	}
	if rec.Time.IsZero() {
		rec.Time = time.Now()
	}
	return rec, true
}

// Done is closed when the helper exits.
func (p *Process) Done() <-chan struct{} { return p.done }

// Err is how the helper exited, once Done is closed (nil before).
func (p *Process) Err() error {
	select {
	case <-p.done:
		return p.err
	default:
		return nil
	}
}

// Stop ends the helper: closing stdin asks it to exit; one that does not is killed after stopGrace.
func (p *Process) Stop() {
	p.once.Do(func() {
		p.stdin.Close()
		select {
		case <-p.done:
		case <-time.After(stopGrace):
			if p.cmd.Process != nil {
				_ = p.cmd.Process.Kill()
			}
			<-p.done
		}
	})
}

const stopGrace = 2 * time.Second
