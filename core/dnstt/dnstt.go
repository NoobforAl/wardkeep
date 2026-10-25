// Package dnstt runs a DNS tunnel client: a local TCP port whose connections travel to a dnstt server inside DNS
// queries (to a resolver, which asks the server's zone). It is for networks where nothing but DNS gets out. The
// protocol is dnstt's (Noise over KCP over DNS, see third_party/dnstt); this package keeps a session up through the
// first resolver that works and switches to the next when it dies.
package dnstt

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/NoobforAl/omnitun/third_party/dnstt/client"
	"github.com/NoobforAl/omnitun/third_party/dnstt/dns"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
)

// Config is one tunnel.
type Config struct {
	// Domain is the DNS zone delegated to the tunnel server, such as t.example.com.
	Domain string
	// PubKey is the server's public key, 64 hex digits (omnitun-server prints it).
	PubKey string
	// Resolvers are tried in order: udp://IP:port, tls://host:port, https://host/path.
	Resolvers []string
	// UTLS picks the TLS fingerprints for DoH and DoT ("3*Firefox,2*Chrome", "none"); empty is dnstt's default mix.
	UTLS string
}

// Key is the server's public key as bytes.
func (c Config) Key() ([]byte, error) {
	k, err := noise.DecodeKey(c.PubKey)
	if err != nil {
		return nil, fmt.Errorf("the server key is not %d hex digits: %w", noise.KeyLen*2, err)
	}
	return k, nil
}

// validDomain reports whether s is a host name: labels of letters, digits and hyphens, 63 bytes at most each.
func validDomain(s string) bool {
	s = strings.TrimSuffix(s, ".")
	if s == "" || len(s) > 253 {
		return false
	}
	if _, err := dns.ParseName(s); err != nil {
		return false
	}
	for _, label := range strings.Split(s, ".") {
		if label == "" || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return false
		}
		for _, r := range label {
			if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-') {
				return false
			}
		}
	}
	return true
}

// Validate checks the domain, the key and every resolver.
func (c Config) Validate() error {
	if !validDomain(c.Domain) {
		return fmt.Errorf("%q is not a domain name", c.Domain)
	}
	if _, err := c.Key(); err != nil {
		return err
	}
	if len(c.Resolvers) == 0 {
		return errors.New("at least one resolver is needed")
	}
	for _, r := range c.Resolvers {
		if _, err := client.ParseResolver(r); err != nil {
			return err
		}
	}
	return nil
}

// Options are how a tunnel opens its sockets and where it logs.
type Options struct {
	// Dial and ListenPacket open the sockets of DoH, DoT and UDP resolvers (nil: ordinary ones).
	Dial         client.DialFunc
	ListenPacket client.ListenPacketFunc
	// Deferred holds back every connection attempt until Bind is called: the local port exists at once (a
	// proxy configuration can name it) while the sockets it will use do not exist yet.
	Deferred bool
	// Logf receives the tunnel's log lines (nil: none).
	Logf func(format string, args ...any)
}

// Process is a running tunnel: a local port that carries connections to the server.
type Process struct {
	// Addr is the local TCP address (127.0.0.1:port); every connection to it is carried to the server's upstream.
	Addr string

	cfg  Config
	key  []byte
	logf func(string, ...any)
	ln   *net.TCPListener

	ctx    context.Context
	cancel context.CancelFunc
	done   chan struct{}

	bindOnce sync.Once
	bound    chan struct{}
	bindMu   sync.RWMutex
	dial     client.DialFunc
	listen   client.ListenPacketFunc

	mu        sync.Mutex
	cond      *sync.Cond
	sess      *client.Session
	active    string
	lastErr   error
	readyOnce sync.Once
	ready     chan struct{}
}

// Start opens the local port and starts connecting in the background.
func Start(parent context.Context, cfg Config, opts Options) (*Process, error) {
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	key, _ := cfg.Key()
	ln, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		return nil, fmt.Errorf("opening the local port: %w", err)
	}
	ctx, cancel := context.WithCancel(parent)
	p := &Process{
		Addr: ln.Addr().String(), cfg: cfg, key: key, ln: ln, ctx: ctx, cancel: cancel,
		done: make(chan struct{}), bound: make(chan struct{}), ready: make(chan struct{}),
		dial: opts.Dial, listen: opts.ListenPacket, logf: opts.Logf,
	}
	if p.logf == nil {
		p.logf = func(string, ...any) {}
	}
	p.cond = sync.NewCond(&p.mu)
	if !opts.Deferred {
		p.bindOnce.Do(func() { close(p.bound) })
	}
	go p.accept()
	go p.run()
	return p, nil
}

// Bind gives a deferred tunnel the functions that open its sockets, and lets it start connecting.
func (p *Process) Bind(dial client.DialFunc, listen client.ListenPacketFunc) {
	p.bindOnce.Do(func() {
		p.bindMu.Lock()
		p.dial, p.listen = dial, listen
		p.bindMu.Unlock()
		close(p.bound)
	})
}

// Ready waits until a session is up: the Noise handshake with the server worked through some resolver.
func (p *Process) Ready(ctx context.Context) error {
	select {
	case <-p.ready:
		return nil
	case <-p.done:
		return p.Err()
	case <-ctx.Done():
		if err := p.Err(); err != nil {
			return fmt.Errorf("%w (last error: %v)", ctx.Err(), err)
		}
		return ctx.Err()
	}
}

// Done is closed when the process has been stopped.
func (p *Process) Done() <-chan struct{} { return p.done }

// Active is the resolver the tunnel is using, empty while it has none.
func (p *Process) Active() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.active
}

// Err is the last reason a session could not be opened or ended.
func (p *Process) Err() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.lastErr
}

// Stop closes the local port and the session.
func (p *Process) Stop() {
	p.cancel()
	p.ln.Close()
	p.mu.Lock()
	p.cond.Broadcast()
	p.mu.Unlock()
	<-p.done
}

// clientConfig is the session's configuration for one resolver, with sockets that wait for Bind.
func (p *Process) clientConfig(resolver string) client.Config {
	return client.Config{
		Domain: p.cfg.Domain, PubKey: p.key, Resolver: resolver, UTLS: p.cfg.UTLS,
		Dial: func(ctx context.Context, network, addr string) (net.Conn, error) {
			if err := p.waitBound(ctx); err != nil {
				return nil, err
			}
			p.bindMu.RLock()
			dial := p.dial
			p.bindMu.RUnlock()
			if dial == nil {
				dial = func(ctx context.Context, network, addr string) (net.Conn, error) {
					return (&net.Dialer{}).DialContext(ctx, network, addr)
				}
			}
			return dial(ctx, network, addr)
		},
		ListenPacket: func(ctx context.Context, network, remote string) (net.PacketConn, error) {
			if err := p.waitBound(ctx); err != nil {
				return nil, err
			}
			p.bindMu.RLock()
			listen := p.listen
			p.bindMu.RUnlock()
			if listen == nil {
				return net.ListenPacket(network, "")
			}
			return listen(ctx, network, remote)
		},
	}
}

func (p *Process) waitBound(ctx context.Context) error {
	select {
	case <-p.bound:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-p.ctx.Done():
		return p.ctx.Err()
	}
}

const (
	openTimeout = 25 * time.Second
	maxBackoff  = 20 * time.Second
)

// racers is how many resolvers are tried at once when connecting: a dead one costs nothing but its timeout, which
// the others do not wait for.
const racers = 3

// openAny opens a session through the first of the resolvers that answers, trying up to racers of them (the ones
// from index start on) at the same time. It returns the session and the index of its resolver.
func (p *Process) openAny(start int) (*client.Session, int, error) {
	n := len(p.cfg.Resolvers)
	k := min(n, racers)
	ctx, cancel := context.WithTimeout(p.ctx, openTimeout)
	defer cancel()
	type result struct {
		sess *client.Session
		idx  int
		err  error
	}
	ch := make(chan result, k)
	for j := 0; j < k; j++ {
		idx := (start + j) % n
		go func() {
			sess, err := client.Open(ctx, p.clientConfig(p.cfg.Resolvers[idx]))
			if err != nil {
				err = fmt.Errorf("%s: %w", p.cfg.Resolvers[idx], err)
			}
			ch <- result{sess, idx, err}
		}()
	}
	var winner *result
	var firstErr error
	for j := 0; j < k; j++ {
		r := <-ch
		switch {
		case r.err != nil:
			if firstErr == nil {
				firstErr = r.err
			}
		case winner == nil:
			winner = &r
			cancel() // the others are not needed
		default:
			r.sess.Close()
		}
	}
	if winner == nil {
		return nil, 0, firstErr
	}
	return winner.sess, winner.idx, nil
}

// run keeps one session up: it stays with a resolver while it works, tries it first again when the session dies,
// and moves on to the next ones when none of the first few connect.
func (p *Process) run() {
	defer close(p.done)
	start, failures := 0, 0
	for p.ctx.Err() == nil {
		sess, idx, err := p.openAny(start)
		if err != nil {
			if p.ctx.Err() != nil {
				return
			}
			p.setErr(err)
			p.logf("DNS tunnel: %v", err)
			failures++
			start = (start + racers) % len(p.cfg.Resolvers)
			wait := min(time.Duration(failures)*2*time.Second, maxBackoff)
			select {
			case <-time.After(wait):
			case <-p.ctx.Done():
				return
			}
			continue
		}
		failures = 0
		resolver := p.cfg.Resolvers[idx]
		p.logf("DNS tunnel: connected through %s", resolver)
		p.mu.Lock()
		p.sess, p.active, p.lastErr = sess, resolver, nil
		p.cond.Broadcast()
		p.mu.Unlock()
		p.readyOnce.Do(func() { close(p.ready) })
		select {
		case <-sess.Done():
			p.setErr(fmt.Errorf("%s: the session ended", resolver))
			p.logf("DNS tunnel: the session through %s ended", resolver)
		case <-p.ctx.Done():
		}
		p.mu.Lock()
		p.sess, p.active = nil, ""
		p.mu.Unlock()
		sess.Close()
		// The same resolver is tried first again: a session that ended is more often a hiccup than a dead resolver.
		start = idx
	}
}

func (p *Process) setErr(err error) {
	p.mu.Lock()
	p.lastErr = err
	p.mu.Unlock()
}

// session waits (up to wait) for a session to be up.
func (p *Process) session(wait time.Duration) *client.Session {
	deadline := time.AfterFunc(wait, func() {
		p.mu.Lock()
		p.cond.Broadcast()
		p.mu.Unlock()
	})
	defer deadline.Stop()
	end := time.Now().Add(wait)
	p.mu.Lock()
	defer p.mu.Unlock()
	for p.sess == nil && p.ctx.Err() == nil && time.Now().Before(end) {
		p.cond.Wait()
	}
	return p.sess
}

// accept hands each local connection to the current session.
func (p *Process) accept() {
	for {
		c, err := p.ln.AcceptTCP()
		if err != nil {
			if p.ctx.Err() != nil || errors.Is(err, net.ErrClosed) {
				return
			}
			continue
		}
		go func() {
			defer c.Close()
			// A connection that arrives while the tunnel is still coming up waits for it, up to a limit.
			sess := p.session(30 * time.Second)
			if sess == nil {
				return
			}
			if err := sess.Forward(c); err != nil {
				p.logf("DNS tunnel: %v", err)
			}
		}()
	}
}

// ScanResult is how one candidate resolver did.
type ScanResult struct {
	Resolver string `json:"resolver"`
	// Ms is the time the tunnel handshake took, in milliseconds; 0 when it did not work.
	Ms  int    `json:"ms"`
	Err string `json:"error,omitempty"`
}

// DefaultResolvers are tried by a scan that is given none: the large public resolvers, and a few that answer
// inside Iran when the foreign ones do not (Shecan, Electro).
var DefaultResolvers = []string{
	"udp://8.8.8.8:53", "udp://1.1.1.1:53", "udp://9.9.9.9:53", "udp://208.67.222.222:53",
	"udp://94.140.14.14:53", "udp://178.22.122.100:53", "udp://185.51.200.2:53", "udp://78.157.42.100:53",
	"https://dns.google/dns-query", "https://cloudflare-dns.com/dns-query", "https://dns.quad9.net/dns-query",
	"tls://dns.google:853", "tls://1.1.1.1:853", "tls://dns.quad9.net:853",
}

// Scan opens a session through each candidate (the resolvers of cfg are ignored) and reports which work and how
// fast, the working ones first. A handshake that completes went through the resolver to the server and back, so
// a resolver that passes is one the tunnel can use. parallel limits how many are tried at once; each gets
// perResolver to answer.
func Scan(ctx context.Context, cfg Config, candidates []string, opts Options, parallel int, perResolver time.Duration) ([]ScanResult, error) {
	if len(candidates) == 0 {
		candidates = DefaultResolvers
	}
	if !validDomain(cfg.Domain) {
		return nil, fmt.Errorf("%q is not a domain name", cfg.Domain)
	}
	key, err := cfg.Key()
	if err != nil {
		return nil, err
	}
	if parallel <= 0 {
		parallel = 6
	}
	if perResolver <= 0 {
		perResolver = 12 * time.Second
	}
	results := make([]ScanResult, len(candidates))
	sem := make(chan struct{}, parallel)
	var wg sync.WaitGroup
	for i, r := range candidates {
		results[i].Resolver = r
		if _, err := client.ParseResolver(r); err != nil {
			results[i].Err = err.Error()
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-sem }()
			cctx, cancel := context.WithTimeout(ctx, perResolver)
			defer cancel()
			d, err := client.Probe(cctx, client.Config{
				Domain: cfg.Domain, PubKey: key, Resolver: r, UTLS: cfg.UTLS, Dial: opts.Dial, ListenPacket: opts.ListenPacket,
			})
			if err != nil {
				results[i].Err = err.Error()
				return
			}
			results[i].Ms = max(int(d.Milliseconds()), 1)
		}()
	}
	wg.Wait()
	sort.SliceStable(results, func(a, b int) bool {
		ra, rb := results[a], results[b]
		if (ra.Ms > 0) != (rb.Ms > 0) {
			return ra.Ms > 0
		}
		return ra.Ms < rb.Ms
	})
	return results, ctx.Err()
}
