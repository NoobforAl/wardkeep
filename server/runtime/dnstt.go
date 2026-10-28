package runtime

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/NoobforAl/omnitun/server/logs"
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
	proto := st.Server.Protocols[store.DNSTTKey]
	if proto == nil || !proto.Enabled || len(st.ActiveUsers(time.Now())) == 0 {
		return
	}
	conf := st.Server.DNSTT
	notStarted := logs.Record{Msg: "the DNS tunnel did not start", Target: "dnstt", Op: "start", Code: "START_FAILED"}
	if conf.Domain == "" {
		notStarted.Msg += ": it has no domain (omnitun-server dnstt domain <name>)"
		s.failed(true, notStarted, nil)
		return
	}
	if err := conf.Valid(); err != nil {
		s.failed(true, notStarted, err)
		return
	}
	key, err := noise.DecodeKey(conf.PrivateKey)
	if err != nil {
		notStarted.Msg += ": its key is damaged"
		s.failed(true, notStarted, nil) // the error would print the key
		return
	}
	conn, err := net.ListenPacket("udp", ":"+strconv.Itoa(proto.Port))
	if err != nil {
		hint := ""
		if errors.Is(err, syscall.EADDRINUSE) || strings.Contains(err.Error(), "address already in use") {
			hint = " (something else holds that port; on Ubuntu systemd-resolved listens on 127.0.0.53:53 and may need `DNSStubListener=no` in /etc/systemd/resolved.conf)"
		}
		notStarted.Msg += fmt.Sprintf(": UDP port %d is not free%s", proto.Port, hint)
		s.failed(true, notStarted, err)
		return
	}
	dnsttserver.SetLogf(s.dnsttLogf)
	ctx, cancel := context.WithCancel(context.Background())
	sc := &dnsttSidecar{cancel: cancel, done: make(chan struct{})}
	upstream := net.JoinHostPort("127.0.0.1", strconv.Itoa(conf.UpstreamPort))
	go func() {
		defer close(sc.done)
		defer s.recovered("dnstt", "serve")
		if err := dnsttserver.Serve(ctx, conn, dnsttserver.Config{Domain: conf.Domain, PrivKey: key, Upstream: upstream}); err != nil && ctx.Err() == nil {
			s.failed(true, logs.Record{Msg: "the DNS tunnel stopped", Target: "dnstt", Op: "serve", Code: "STOPPED"}, err)
		}
	}()
	s.dnstt = sc
	s.logf(logs.LevelInfo, "serving the DNS tunnel on UDP port %d", proto.Port)
}

// stopDNSTTLocked stops the DNS tunnel's front end, if it runs.
func (s *Server) stopDNSTTLocked() {
	if sc := s.dnstt; sc != nil {
		s.dnstt = nil
		sc.cancel()
		<-sc.done
	}
}
