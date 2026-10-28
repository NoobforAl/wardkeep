// Package tor runs Tor for Wardkeep: the Arti client (the Rust `omnitun-tor`
// binary from tor/) behind a local SOCKS5 port, plus bridge pluggable
// transports run in-process in Go (obfs4, WebTunnel, Snowflake, meek).
package tor

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NoobforAl/omnitun/core/logrec"
)

// Config starts Tor.
type Config struct {
	// Bin is the omnitun-tor executable; empty uses FindBinary.
	Bin string
	// DataDir keeps Arti's state and directory cache between runs (faster
	// bootstraps).
	DataDir string
	// Bridges are bridge lines; empty connects to Tor directly.
	Bridges []string
	// Dial makes the pluggable transports' outbound connections.
	Dial DialFunc
	// OnBootstrap receives bootstrap progress (0-100) and Arti's description.
	OnBootstrap func(percent int, status string)
	// OnPath receives the circuit the traffic rides whenever it changes: the relays in order, each with
	// its role and (when known) country.
	OnPath func(path []Hop)
	// OnLog receives omnitun-tor's log records (its stdout "log" events, with their own level and extra keys) and,
	// as errors, anything it writes to stderr (which it does only when something unexpected happens).
	OnLog func(logrec.Record)
	// LogLevel is passed as --log-level (trace, debug, info, warn, error, fatal); empty leaves omnitun-tor's default
	// (error).
	LogLevel string
}

// Process is a running Tor client.
type Process struct {
	// SocksAddr is the local SOCKS5 address (127.0.0.1:port).
	SocksAddr string

	cmd   *exec.Cmd
	stdin io.WriteCloser
	pts   *Transports
	ready chan error
	done  chan struct{}
	once  sync.Once
	err   error
}

// Hop is one relay of a Tor circuit.
type Hop struct {
	// Role is "bridge" or "guard" (the first hop), "middle" or "exit".
	Role string `json:"role"`
	// Country is the upper-case ISO code of where the relay is; empty when unknown (a bridge behind
	// Snowflake or a front has no real address).
	Country string `json:"country"`
}

type event struct {
	Event   string `json:"event"`
	Socks   string `json:"socks"`
	Percent int    `json:"percent"`
	Status  string `json:"status"`
	Blocked string `json:"blocked"`
	Message string `json:"message"`
	Hops    []struct {
		Role    string  `json:"role"`
		Country *string `json:"country"`
	} `json:"hops"`
}

// FindBinary locates omnitun-tor: $OMNITUN_TOR_BIN, then next to the running
// executable, then $PATH.
func FindBinary() (string, error) {
	if p := os.Getenv("OMNITUN_TOR_BIN"); p != "" {
		return p, nil
	}
	name := "omnitun-tor"
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
	return "", errors.New("the Tor client (omnitun-tor) is not installed")
}

// Start launches the transports and Arti; it returns once Arti's SOCKS port
// is listening. Use Ready to wait for the bootstrap.
func Start(cfg Config) (*Process, error) {
	bin := cfg.Bin
	if bin == "" {
		var err error
		if bin, err = FindBinary(); err != nil {
			return nil, err
		}
	}
	if err := os.MkdirAll(cfg.DataDir, 0o700); err != nil {
		return nil, err
	}
	args := []string{"--data", cfg.DataDir, "--socks-port", "0"}
	if cfg.LogLevel != "" {
		args = append(args, "--log-level", cfg.LogLevel)
	}
	var bridges []string
	for _, b := range cfg.Bridges {
		if b = NormalizeBridge(b); b != "" {
			bridges = append(bridges, b)
			args = append(args, "--bridge", b)
		}
	}
	proc := &Process{ready: make(chan error, 1), done: make(chan struct{})}
	if names := TransportsFor(bridges); len(names) > 0 {
		pts, err := StartTransports(filepath.Join(cfg.DataDir, "pt"), names, cfg.Dial)
		if err != nil {
			return nil, err
		}
		proc.pts = pts
		keys := make([]string, 0, len(pts.Addrs))
		for k := range pts.Addrs {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			args = append(args, "--transport", k+"="+pts.Addrs[k])
		}
	}

	proc.cmd = exec.Command(bin, args...)
	hideWindow(proc.cmd)
	stdout, err := proc.cmd.StdoutPipe()
	if err != nil {
		proc.closeTransports()
		return nil, err
	}
	// Closing stdin tells omnitun-tor to exit (also when this process dies).
	if proc.stdin, err = proc.cmd.StdinPipe(); err != nil {
		proc.closeTransports()
		return nil, err
	}
	stderr, _ := proc.cmd.StderrPipe()
	if err := proc.cmd.Start(); err != nil {
		proc.closeTransports()
		return nil, fmt.Errorf("start Tor: %w", err)
	}

	listening := make(chan string, 1)
	go func() {
		// A panic here (in a handler) must not leave Tor blocked on a full pipe: the rest is drained unread.
		defer io.Copy(io.Discard, stdout)
		defer logrec.Recover(logrec.SourceTor, "run", cfg.OnLog)
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
				listening <- ev.Socks
			case "bootstrap":
				if cfg.OnBootstrap != nil {
					status := ev.Status
					if ev.Blocked != "" {
						status += " (" + ev.Blocked + ")"
					}
					cfg.OnBootstrap(ev.Percent, status)
				}
			case "path":
				if cfg.OnPath != nil && len(ev.Hops) > 0 {
					path := make([]Hop, len(ev.Hops))
					for i, h := range ev.Hops {
						path[i].Role = h.Role
						if h.Country != nil {
							path[i].Country = strings.ToUpper(*h.Country)
						}
					}
					cfg.OnPath(path)
				}
			case "ready":
				proc.ready <- nil
			case "error":
				proc.ready <- errors.New(ev.Message)
			}
		}
	}()
	if stderr != nil {
		go func() {
			defer io.Copy(io.Discard, stderr)
			defer logrec.Recover(logrec.SourceTor, "run", cfg.OnLog)
			sc := bufio.NewScanner(stderr)
			for sc.Scan() {
				if cfg.OnLog != nil && strings.TrimSpace(sc.Text()) != "" {
					cfg.OnLog(stderrRecord(sc.Text()))
				}
			}
		}()
	}
	go func() {
		err := proc.cmd.Wait()
		proc.err = err
		select {
		case proc.ready <- fmt.Errorf("Tor exited: %v", err):
		default:
		}
		close(proc.done)
	}()

	select {
	case addr := <-listening:
		proc.SocksAddr = addr
		return proc, nil
	case <-proc.done:
		proc.closeTransports()
		return nil, fmt.Errorf("Tor exited at start: %v", proc.err)
	}
}

// parseLogEvent reads a stdout line {"event":"log", <record keys>} into a record; keys outside the contract stay
// in Extra (without "event").
func parseLogEvent(line []byte) (logrec.Record, bool) {
	var rec logrec.Record
	if json.Unmarshal(line, &rec) != nil {
		return rec, false
	}
	delete(rec.Extra, "event")
	if rec.Source == "" {
		rec.Source = logrec.SourceTor
	}
	if rec.Time.IsZero() {
		rec.Time = time.Now()
	}
	return rec, true
}

// stderrRecord is a line omnitun-tor wrote to stderr: only unexpected output goes there, so it is an error.
func stderrRecord(line string) logrec.Record {
	return logrec.Record{Time: time.Now(), Level: logrec.LevelError, Source: logrec.SourceTor, Msg: strings.TrimSpace(line)}
}

// Ready waits for the bootstrap to finish.
func (p *Process) Ready(ctx context.Context) error {
	select {
	case err := <-p.ready:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Done is closed when the Tor process exits.
func (p *Process) Done() <-chan struct{} { return p.done }

// Err is how the Tor process exited, once Done is closed (nil before).
func (p *Process) Err() error {
	select {
	case <-p.done:
		return p.err
	default:
		return nil
	}
}

// Stop ends Tor and its transports.
func (p *Process) Stop() {
	p.once.Do(func() {
		p.stdin.Close()
		if p.cmd.Process != nil {
			p.cmd.Process.Kill()
		}
		<-p.done
		p.closeTransports()
	})
}

func (p *Process) closeTransports() {
	if p.pts != nil {
		p.pts.Close()
	}
}

// Port returns the SOCKS port number.
func (p *Process) Port() int {
	_, port, _ := cutLast(p.SocksAddr, ":")
	n, _ := strconv.Atoi(port)
	return n
}

func cutLast(s, sep string) (string, string, bool) {
	for i := len(s) - len(sep); i >= 0; i-- {
		if s[i:i+len(sep)] == sep {
			return s[:i], s[i+len(sep):], true
		}
	}
	return s, "", false
}
