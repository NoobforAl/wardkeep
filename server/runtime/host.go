package runtime

import (
	"time"

	"github.com/NoobforAl/omnitun/server/hostproto"
	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/store"
	"github.com/NoobforAl/omnitun/server/tlsfiles"
)

// startHostLocked starts the host-level protocols (SSTP, IKEv2, AmneziaWG) that are
// enabled and have users, and sets up NAT for their client networks. A
// failure is logged and leaves the others running: these protocols need the
// host's cooperation (Linux, CAP_NET_ADMIN, nftables or iptables) that the
// sing-box ones do not.
func (s *Server) startHostLocked(st *store.State) {
	users := st.ActiveUsers(time.Now())
	// The DNSCrypt resolver answers whoever reaches it and needs no account.
	if p := st.Server.Protocols[store.DNSCryptKey]; len(users) == 0 && (p == nil || !p.Enabled) {
		return
	}
	var pools []string
	ipv6 := false
	for _, key := range hostproto.Keys() {
		proto := st.Server.Protocols[key]
		if proto == nil || !proto.Enabled || (len(users) == 0 && key != store.DNSCryptKey) {
			continue
		}
		cfg := hostproto.Config{
			Env: serverconf.Env(st, s.store), Port: proto.Port, Users: serverconf.Accounts(users), DataDir: s.store.Dir,
			Runner: s.runner, Logf: s.hostLogf,
		}
		if key == "sstp" || key == "ikev2" {
			domain := ""
			if st.Server.ACMEActive() {
				domain = st.Server.ACME.Domain
			}
			src := tlsfiles.New(serverconf.ACMEDir(s.store), domain, s.store.Path(st.Server.CertFile), s.store.Path(st.Server.KeyFile))
			var err error
			noCertificate := logs.Record{Msg: key + " did not start: no certificate", Target: key, Op: "start", Code: "NO_CERTIFICATE"}
			if cfg.CertFile, cfg.KeyFile, err = src.Paths(); err != nil {
				s.failed(true, noCertificate, err)
				continue
			}
			if cfg.CertPEM, cfg.KeyPEM, err = src.PEM(); err != nil {
				s.failed(true, noCertificate, err)
				continue
			}
		}
		srv, err := hostproto.Start(key, cfg)
		if err != nil {
			s.failed(true, logs.Record{
				Msg:    key + " did not start (it needs Linux and CAP_NET_ADMIN; see `omnitun-server install`)",
				Target: key, Op: "start", Code: "START_FAILED",
			}, err)
			continue
		}
		if s.hosts == nil {
			s.hosts = map[string]hostproto.Server{}
		}
		s.hosts[key] = srv
		if m, ok := srv.(hostproto.Meter); ok {
			s.meters.add(key, m)
		}
		if pool := srv.Pool(); pool != "" {
			pools = append(pools, pool)
		}
		if d, ok := srv.(hostproto.DualStack); ok && d.Pool6() != "" {
			pools = append(pools, d.Pool6())
			ipv6 = true
		}
		s.logf(logs.LevelInfo, "serving %s on port %d", key, proto.Port)
	}
	if len(pools) == 0 {
		return
	}
	undo, err := hostproto.EnableNAT(s.runner, s.store.Dir, pools)
	if err != nil {
		s.failed(true, logs.Record{
			Msg:    "NAT for the clients of SSTP, IKEv2 and AmneziaWG failed (they can connect but will not reach the internet)",
			Target: "nat", Op: "start", Code: "NAT_FAILED",
		}, err)
		return
	}
	s.undoNAT = undo
	if !hostproto.ForwardingEnabled() {
		s.logf(logs.LevelWarn, "IP forwarding is off; enable it with `sysctl -w net.ipv4.ip_forward=1` or run `omnitun-server install`")
	}
	if ipv6 && !hostproto.ForwardingEnabled6() {
		s.logf(logs.LevelWarn, "IPv6 forwarding is off, so IPv6 clients cannot get out; enable it with `sysctl -w net.ipv6.conf.all.forwarding=1` "+
			"(and `net.ipv6.conf.all.accept_ra=2` if this host gets its IPv6 address from a router advertisement, which forwarding would otherwise switch off)")
	}
}

// stopHostLocked stops the host-level servers and removes their NAT rules.
func (s *Server) stopHostLocked() {
	s.stopDNSTTLocked()
	for key, srv := range s.hosts {
		s.meters.remove(key, s.tracker) // the last reading, while the server still counts
		srv.Close()
		delete(s.hosts, key)
	}
	if s.undoNAT != nil {
		s.undoNAT()
		s.undoNAT = nil
	}
}
