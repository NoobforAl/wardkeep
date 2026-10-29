package dnscrypt

import (
	"container/list"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/miekg/dns"
)

// ForwarderConfig sets up a Forwarder.
type ForwarderConfig struct {
	// Stamp is the DNSCrypt resolver ("sdns://...").
	Stamp string
	// Relay makes the exchange Anonymized DNSCrypt: a relay stamp or "ip:port". Empty for none.
	Relay string
	// Dial opens the sockets to the resolver or relay; nil dials directly.
	Dial Dialer
	// TCPOnly keeps to TCP (Tor has no UDP).
	TCPOnly bool
	// Listen is the loopback address to serve on, default "127.0.0.1:0". The
	// same port is used for UDP and TCP.
	Listen string
	// MaxInflight bounds the queries being answered at once; further ones get
	// SERVFAIL. Default 64.
	MaxInflight int
	// CacheEntries bounds the answer cache, default 512; negative turns it off.
	CacheEntries int
	// Timeout is the wait for the resolver per attempt, default 5 s.
	Timeout time.Duration
	// Logf receives log lines; may be nil.
	Logf func(level, format string, args ...any)
}

// Stats counts what the forwarder did.
type Stats struct {
	Queries   uint64    // queries received
	Answered  uint64    // answered by the resolver
	CacheHits uint64    // answered from the cache
	Failed    uint64    // answered SERVFAIL
	LastError string    // the latest failure, empty if none yet
	LastOK    time.Time // when the resolver last answered
}

// Forwarder is a DNS server on the loopback interface that answers every query
// through DNSCrypt. If the resolver cannot be reached the query fails with
// SERVFAIL: there is no fallback to a plain resolver.
type Forwarder struct {
	cfg      ForwarderConfig
	up       *Upstream
	name     string
	relayed  bool
	inflight chan struct{}
	cache    *answerCache

	mu      sync.Mutex
	udp     *net.UDPConn
	tcp     net.Listener
	conns   map[net.Conn]struct{}
	closed  bool
	ctx     context.Context
	cancel  context.CancelFunc
	wg      sync.WaitGroup
	lastErr string
	lastOK  time.Time

	queries, answered, hits, failed atomic.Uint64
}

// NewForwarder checks the stamps and prepares the forwarder; Start opens the sockets.
func NewForwarder(cfg ForwarderConfig) (*Forwarder, error) {
	st, err := ParseDNSCryptStamp(cfg.Stamp)
	if err != nil {
		return nil, err
	}
	uc := UpstreamConfig{Stamp: st, Dial: cfg.Dial, TCPOnly: cfg.TCPOnly, Timeout: cfg.Timeout, Logf: cfg.Logf}
	if strings.TrimSpace(cfg.Relay) != "" {
		relay, err := ParseRelayStamp(cfg.Relay)
		if err != nil {
			return nil, err
		}
		uc.Relay = &relay
	}
	up, err := NewUpstream(uc)
	if err != nil {
		return nil, err
	}
	if cfg.Listen == "" {
		cfg.Listen = "127.0.0.1:0"
	}
	if cfg.MaxInflight <= 0 {
		cfg.MaxInflight = 64
	}
	fwd := &Forwarder{
		cfg: cfg, up: up, name: st.Name(), relayed: uc.Relay != nil,
		inflight: make(chan struct{}, cfg.MaxInflight),
		conns:    map[net.Conn]struct{}{},
	}
	fwd.ctx, fwd.cancel = context.WithCancel(context.Background())
	if cfg.CacheEntries >= 0 {
		n := cfg.CacheEntries
		if n == 0 {
			n = 512
		}
		fwd.cache = newAnswerCache(n)
	}
	return fwd, nil
}

// Resolver is the resolver's short name, for display.
func (f *Forwarder) Resolver() string { return f.name }

// Anonymized reports whether queries go through a relay.
func (f *Forwarder) Anonymized() bool { return f.relayed }

func (f *Forwarder) log(level, format string, args ...any) {
	if f.cfg.Logf != nil {
		f.cfg.Logf(level, format, args...)
	}
}

// Start opens the UDP and TCP sockets on the same loopback port and serves.
func (f *Forwarder) Start() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.udp != nil || f.closed {
		return errors.New("dnscrypt: forwarder already started or closed")
	}
	var lastErr error
	for range 10 {
		ln, err := net.Listen("tcp", f.cfg.Listen)
		if err != nil {
			return err
		}
		// A fixed port is tried once; with port 0 another port is picked on a clash.
		udpAddr := ln.Addr().(*net.TCPAddr)
		pc, err := net.ListenUDP("udp", &net.UDPAddr{IP: udpAddr.IP, Port: udpAddr.Port, Zone: udpAddr.Zone})
		if err != nil {
			ln.Close()
			lastErr = err
			if _, p, _ := net.SplitHostPort(f.cfg.Listen); p != "0" {
				return err
			}
			continue
		}
		f.tcp, f.udp = ln, pc
		f.wg.Add(2)
		go f.serveUDP(pc)
		go f.serveTCP(ln)
		return nil
	}
	return fmt.Errorf("dnscrypt: no free loopback port: %w", lastErr)
}

// Addr is the address the forwarder listens on, "127.0.0.1:port".
func (f *Forwarder) Addr() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.tcp == nil {
		return ""
	}
	return f.tcp.Addr().String()
}

// Check fetches the resolver's certificate. It fails when the resolver cannot
// be reached or its key is not the one in the stamp.
func (f *Forwarder) Check(ctx context.Context) error {
	err := f.up.Check(ctx)
	if err != nil {
		f.noteFailure(err)
	} else {
		f.noteOK()
	}
	return err
}

// Retry makes the next query try the resolver again at once, instead of
// waiting out the pause after a failure.
func (f *Forwarder) Retry() { f.up.Retry() }

// Stats returns the counters.
func (f *Forwarder) Stats() Stats {
	f.mu.Lock()
	defer f.mu.Unlock()
	return Stats{
		Queries: f.queries.Load(), Answered: f.answered.Load(), CacheHits: f.hits.Load(), Failed: f.failed.Load(),
		LastError: f.lastErr, LastOK: f.lastOK,
	}
}

func (f *Forwarder) noteFailure(err error) {
	f.mu.Lock()
	first := f.lastErr == ""
	f.lastErr = err.Error()
	f.mu.Unlock()
	if first {
		f.log("warn", "DNSCrypt (%s): %v", f.name, err)
	}
}

func (f *Forwarder) noteOK() {
	f.mu.Lock()
	recovered := f.lastErr != ""
	f.lastErr = ""
	f.lastOK = time.Now()
	f.mu.Unlock()
	if recovered {
		f.log("info", "DNSCrypt (%s): the resolver answers again", f.name)
	}
}

// Close stops serving and closes the sockets.
func (f *Forwarder) Close() error {
	f.mu.Lock()
	if f.closed {
		f.mu.Unlock()
		return nil
	}
	f.closed = true
	f.cancel()
	udp, tcp := f.udp, f.tcp
	conns := make([]net.Conn, 0, len(f.conns))
	for c := range f.conns {
		conns = append(conns, c)
	}
	f.mu.Unlock()
	if udp != nil {
		udp.Close()
	}
	if tcp != nil {
		tcp.Close()
	}
	for _, c := range conns {
		c.Close()
	}
	f.up.Close()
	f.wg.Wait()
	return nil
}

func (f *Forwarder) serveUDP(pc *net.UDPConn) {
	defer f.wg.Done()
	buf := make([]byte, 65535)
	for {
		n, addr, err := pc.ReadFromUDPAddrPort(buf)
		if err != nil {
			return
		}
		pkt := append([]byte(nil), buf[:n]...)
		f.queries.Add(1)
		select {
		case f.inflight <- struct{}{}:
			f.wg.Go(func() {
				defer func() { <-f.inflight }()
				if resp := f.handle(pkt, true); resp != nil {
					_, _ = pc.WriteToUDPAddrPort(resp, addr)
				}
			})
		default:
			if resp := servfail(pkt); resp != nil {
				f.failed.Add(1)
				_, _ = pc.WriteToUDPAddrPort(resp, addr)
			}
		}
	}
}

func (f *Forwarder) serveTCP(l net.Listener) {
	defer f.wg.Done()
	for {
		conn, err := l.Accept()
		if err != nil {
			return
		}
		f.mu.Lock()
		if f.closed {
			f.mu.Unlock()
			conn.Close()
			return
		}
		f.conns[conn] = struct{}{}
		f.mu.Unlock()
		f.wg.Add(1)
		go f.serveTCPConn(conn)
	}
}

func (f *Forwarder) serveTCPConn(conn net.Conn) {
	defer f.wg.Done()
	defer func() {
		conn.Close()
		f.mu.Lock()
		delete(f.conns, conn)
		f.mu.Unlock()
	}()
	var wmu sync.Mutex
	var queries sync.WaitGroup
	defer queries.Wait()
	for {
		_ = conn.SetReadDeadline(time.Now().Add(30 * time.Second))
		var lenBuf [2]byte
		if _, err := io.ReadFull(conn, lenBuf[:]); err != nil {
			return
		}
		pkt := make([]byte, binary.BigEndian.Uint16(lenBuf[:]))
		if _, err := io.ReadFull(conn, pkt); err != nil {
			return
		}
		f.queries.Add(1)
		reply := func(resp []byte) {
			if resp == nil || len(resp) > 0xffff {
				return
			}
			out := binary.BigEndian.AppendUint16(make([]byte, 0, 2+len(resp)), uint16(len(resp))) //nolint:gosec // G115: checked against 0xffff above
			out = append(out, resp...)
			wmu.Lock()
			_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			_, _ = conn.Write(out)
			wmu.Unlock()
		}
		select {
		case f.inflight <- struct{}{}:
			queries.Go(func() {
				defer func() { <-f.inflight }()
				reply(f.handle(pkt, false))
			})
		default:
			f.failed.Add(1)
			reply(servfail(pkt))
		}
	}
}

// servfail builds a SERVFAIL answer for a packed query, nil if it cannot be read.
func servfail(pkt []byte) []byte {
	q := new(dns.Msg)
	if q.Unpack(pkt) != nil {
		return nil
	}
	r := new(dns.Msg)
	r.SetRcode(q, dns.RcodeServerFailure)
	r.RecursionAvailable = true
	b, err := r.Pack()
	if err != nil {
		return nil
	}
	return b
}

// handle answers one packed query: from the cache, or through DNSCrypt.
func (f *Forwarder) handle(pkt []byte, udp bool) []byte {
	query := new(dns.Msg)
	if err := query.Unpack(pkt); err != nil {
		return nil // not DNS: no answer is better than a wrong one
	}
	if query.Response {
		return nil
	}
	if query.Opcode != dns.OpcodeQuery || len(query.Question) != 1 {
		resp := new(dns.Msg)
		code := dns.RcodeNotImplemented
		if query.Opcode == dns.OpcodeQuery {
			code = dns.RcodeFormatError
		}
		resp.SetRcode(query, code)
		b, _ := resp.Pack()
		return b
	}
	limit := dns.MaxMsgSize
	if udp {
		limit = dns.MinMsgSize
		if o := query.IsEdns0(); o != nil && int(o.UDPSize()) > limit {
			limit = int(o.UDPSize())
		}
	}
	key := cacheKey(query)
	if f.cache != nil {
		if r := f.cache.get(key, query.Id); r != nil {
			f.hits.Add(1)
			return pack(r, limit)
		}
	}
	ctx, cancel := context.WithTimeout(f.ctx, 3*f.timeout())
	defer cancel()
	raw, err := f.up.Exchange(ctx, pkt)
	if err != nil {
		f.failed.Add(1)
		f.noteFailure(err)
		return servfail(pkt)
	}
	resp := new(dns.Msg)
	if err := resp.Unpack(raw); err != nil {
		f.failed.Add(1)
		f.noteFailure(fmt.Errorf("unreadable answer: %w", err))
		return servfail(pkt)
	}
	f.answered.Add(1)
	f.noteOK()
	if f.cache != nil {
		f.cache.put(key, resp)
	}
	return pack(resp, limit)
}

func (f *Forwarder) timeout() time.Duration {
	if f.cfg.Timeout > 0 {
		return f.cfg.Timeout
	}
	return defaultTimeout
}

// pack encodes r, cutting it to limit bytes (and setting TC) if it is larger.
func pack(r *dns.Msg, limit int) []byte {
	if r.Len() > limit {
		r.Truncate(limit)
	}
	b, err := r.Pack()
	if err != nil {
		return nil
	}
	return b
}

// answerCache keeps recent answers until their TTL runs out.
type answerCache struct {
	mu    sync.Mutex
	max   int
	order *list.List // front = most recent
	items map[string]*list.Element
}

type cacheEntry struct {
	key     string
	msg     *dns.Msg
	stored  time.Time
	expires time.Time
}

const (
	cacheMinTTL = 5 * time.Second
	cacheMaxTTL = 10 * time.Minute
	cacheNegTTL = 30 * time.Second
)

func newAnswerCache(max int) *answerCache {
	return &answerCache{max: max, order: list.New(), items: map[string]*list.Element{}}
}

func cacheKey(q *dns.Msg) string {
	qs := q.Question[0]
	flags := byte(0)
	if o := q.IsEdns0(); o != nil && o.Do() {
		flags |= 1
	}
	if q.CheckingDisabled {
		flags |= 2
	}
	return fmt.Sprintf("%s|%d|%d|%d", strings.ToLower(qs.Name), qs.Qtype, qs.Qclass, flags)
}

// ttlOf is how long an answer may be kept; 0 means not at all.
func ttlOf(msg *dns.Msg) time.Duration {
	if msg.Truncated || (msg.Rcode != dns.RcodeSuccess && msg.Rcode != dns.RcodeNameError) {
		return 0
	}
	min := uint32(0)
	seen := false
	for _, section := range [][]dns.RR{msg.Answer, msg.Ns} {
		for _, rr := range section {
			if rr.Header().Rrtype == dns.TypeOPT {
				continue
			}
			if t := rr.Header().Ttl; !seen || t < min {
				min, seen = t, true
			}
		}
	}
	ttl := time.Duration(min) * time.Second
	if !seen || len(msg.Answer) == 0 {
		ttl = cacheNegTTL
		if seen && time.Duration(min)*time.Second < ttl {
			ttl = time.Duration(min) * time.Second
		}
	}
	if ttl > cacheMaxTTL {
		ttl = cacheMaxTTL
	}
	if ttl < cacheMinTTL {
		if min == 0 && seen {
			return 0 // the resolver said do not cache
		}
		ttl = cacheMinTTL
	}
	return ttl
}

func (c *answerCache) put(key string, r *dns.Msg) {
	ttl := ttlOf(r)
	if ttl <= 0 {
		return
	}
	now := time.Now()
	entry := &cacheEntry{key: key, msg: r.Copy(), stored: now, expires: now.Add(ttl)}
	c.mu.Lock()
	defer c.mu.Unlock()
	if old, ok := c.items[key]; ok {
		c.order.Remove(old)
	}
	c.items[key] = c.order.PushFront(entry)
	for c.order.Len() > c.max {
		last := c.order.Back()
		c.order.Remove(last)
		delete(c.items, last.Value.(*cacheEntry).key)
	}
}

// get returns a copy of the cached answer with the query's ID and the TTLs
// counted down, or nil.
func (c *answerCache) get(key string, id uint16) *dns.Msg {
	c.mu.Lock()
	el, ok := c.items[key]
	if !ok {
		c.mu.Unlock()
		return nil
	}
	entry := el.Value.(*cacheEntry)
	now := time.Now()
	if !now.Before(entry.expires) {
		c.order.Remove(el)
		delete(c.items, key)
		c.mu.Unlock()
		return nil
	}
	c.order.MoveToFront(el)
	msg := entry.msg.Copy()
	age := uint32(now.Sub(entry.stored) / time.Second) //nolint:gosec // G115: monotonic, non-negative, and bounded by the entry's TTL
	c.mu.Unlock()
	msg.Id = id
	for _, section := range [][]dns.RR{msg.Answer, msg.Ns, msg.Extra} {
		for _, rr := range section {
			hdr := rr.Header()
			if hdr.Rrtype == dns.TypeOPT {
				continue
			}
			if hdr.Ttl > age {
				hdr.Ttl -= age
			} else {
				hdr.Ttl = 1
			}
		}
	}
	return msg
}
