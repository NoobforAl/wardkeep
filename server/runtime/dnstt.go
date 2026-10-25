package runtime

import (
	"context"
	"errors"
	"net"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/NoobforAl/omnitun/server/store"
	"github.com/NoobforAl/omnitun/third_party/dnstt/noise"
	dnsttserver "github.com/NoobforAl/omnitun/third_party/dnstt/server"
)

// dnsttSidecar is the DNS tunnel's front end: it answers the queries for the zone on UDP and hands the connections
// hidden in them to the loopback SOCKS5 inbound of sing-box (serverconf builds it from the protocol's Inbounds).
type dnsttSidecar struct {
	cancel context.CancelFunc
	done   chan struct{}
}

// startDNSTTLocked starts the DNS tunnel when it is enabled, has a domain and there are users to serve. A failure is
// logged and leaves everything else running: the tunnel needs UDP port 53 (or whatever port it is set to), which
// a host's own resolver often holds.
func (s *Server) startDNSTTLocked(st *store.State) {
	p := st.Server.Protocols[store.DNSTTKey]
	if p == nil || !p.Enabled || len(st.ActiveUsers(time.Now())) == 0 {
		return
	}
	d := st.Server.DNSTT
	if d.Domain == "" {
		s.logf("the DNS tunnel is enabled but has no domain (omnitun-server dnstt domain <name>)")
		return
	}
	if err := d.Valid(); err != nil {
		s.logf("the DNS tunnel did not start: %v", err)
		return
	}
	key, err := noise.DecodeKey(d.PrivateKey)
	if err != nil {
		s.logf("the DNS tunnel did not start: %v", err)
		return
	}
	conn, err := net.ListenPacket("udp", ":"+strconv.Itoa(p.Port))
	if err != nil {
		hint := ""
		if errors.Is(err, syscall.EADDRINUSE) || strings.Contains(err.Error(), "address already in use") {
			hint = " (something else holds that port; on Ubuntu systemd-resolved listens on 127.0.0.53:53 and may need `DNSStubListener=no` in /etc/systemd/resolved.conf)"
		}
		s.logf("the DNS tunnel did not start: UDP port %d: %v%s", p.Port, err, hint)
		return
	}
	dnsttserver.SetLogf(func(format string, args ...any) { s.logf("dnstt: "+format, args...) })
	ctx, cancel := context.WithCancel(context.Background())
	sc := &dnsttSidecar{cancel: cancel, done: make(chan struct{})}
	upstream := net.JoinHostPort("127.0.0.1", strconv.Itoa(d.UpstreamPort))
	go func() {
		defer close(sc.done)
		if err := dnsttserver.Serve(ctx, conn, dnsttserver.Config{Domain: d.Domain, PrivKey: key, Upstream: upstream}); err != nil && ctx.Err() == nil {
			s.logf("the DNS tunnel stopped: %v", err)
		}
	}()
	s.dnstt = sc
	s.logf("serving the DNS tunnel for %s on UDP port %d", d.Domain, p.Port)
}

// stopDNSTTLocked stops the DNS tunnel's front end, if it runs.
func (s *Server) stopDNSTTLocked() {
	if sc := s.dnstt; sc != nil {
		s.dnstt = nil
		sc.cancel()
		<-sc.done
	}
}
