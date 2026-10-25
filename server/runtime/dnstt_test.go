//go:build with_quic && with_utls && with_wireguard && with_gvisor

package runtime

import (
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/engine"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/store"
)

// The DNS tunnel as a user gets it: the server answers DNS on a UDP port and hands the connections to a loopback
// SOCKS5 inbound that wants the user's login. A client built from the profile the server hands out loads a page
// through it; the wrong password does not.
func TestDNSTTServerAndClient(t *testing.T) {
	s, srv := setup(t)
	dnsPort := freeUDP(t)
	if err := s.Update(func(st *store.State) error {
		st.Server.DNSTT.Domain = "t.example.com"
		st.Server.Protocols[store.DNSTTKey].Port = dnsPort
		st.Server.Protocols[store.DNSTTKey].Enabled = true
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if err := srv.Reload(); err != nil {
		t.Fatal(err)
	}
	st, err := s.Load()
	if err != nil {
		t.Fatal(err)
	}

	web := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "ok:"+r.URL.Path)
	}))
	web.Listener.Close()
	if web.Listener, err = net.Listen("tcp", net.JoinHostPort(lanIPv4(t), "0")); err != nil {
		t.Fatal(err)
	}
	web.Start()
	defer web.Close()

	profiles, err := serverconf.Profiles(st, s, st.User("alice"))
	if err != nil {
		t.Fatal(err)
	}
	var tunnel *profile.Profile
	for _, p := range profiles {
		if p.Protocol == profile.DNSTT {
			tunnel = p
		}
	}
	if tunnel == nil {
		t.Fatalf("the server handed out no DNS tunnel profile: %d profiles", len(profiles))
	}
	if tunnel.DNSTT.Domain != "t.example.com" || tunnel.DNSTT.PubKey != st.Server.DNSTT.PublicKey || tunnel.Username != "alice" || tunnel.Password == "" {
		t.Fatalf("profile = %+v %+v", tunnel, tunnel.DNSTT)
	}
	// The server is its own resolver here: all a resolver does is pass the queries on.
	tunnel.DNSTT.Resolvers = []string{"udp://127.0.0.1:" + strconv.Itoa(dnsPort)}

	fetch := func(t *testing.T, p *profile.Profile) error {
		t.Helper()
		if err := p.Validate(); err != nil {
			t.Fatal(err)
		}
		p.EnsureID()
		proxyPort := freeTCP(t)
		e := engine.New(engine.Config{DataDir: tempDir(t)})
		if err := e.Start(p.AsSlice(), singbox.Options{ListenPort: proxyPort, LogLevel: "error", ProxyPrivate: true, Selected: p.ID}); err != nil {
			t.Fatal(err)
		}
		defer e.Stop()
		proxy, _ := url.Parse("socks5://127.0.0.1:" + strconv.Itoa(proxyPort))
		client := &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxy), DisableKeepAlives: true}, Timeout: 12 * time.Second}
		resp, err := client.Get(web.URL + "/data")
		if err != nil {
			return err
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		if string(body) != "ok:/data" {
			t.Fatalf("body = %q", body)
		}
		return nil
	}
	if err := fetch(t, tunnel); err != nil {
		t.Fatalf("through the DNS tunnel: %v", err)
	}
	wrong := *tunnel
	wrong.Password = "not-her-password"
	wrongOpts := *tunnel.DNSTT
	wrong.DNSTT, wrong.ID = &wrongOpts, ""
	if err := fetch(t, &wrong); err == nil {
		t.Fatal("a wrong password should not get through the tunnel's upstream")
	}

	// Disabling the tunnel closes its port.
	if err := s.Update(func(st *store.State) error { st.Server.Protocols[store.DNSTTKey].Enabled = false; return nil }); err != nil {
		t.Fatal(err)
	}
	if err := srv.Reload(); err != nil {
		t.Fatal(err)
	}
	c, err := net.ListenPacket("udp", ":"+strconv.Itoa(dnsPort))
	if err != nil {
		t.Fatalf("the DNS tunnel's port should be free after it is disabled: %v", err)
	}
	c.Close()
}

// A tunnel enabled by hand with no domain is left alone and does not break what the user gets.
func TestDNSTTWithoutADomainIsSkipped(t *testing.T) {
	s, srv := setup(t)
	if err := s.Update(func(st *store.State) error {
		st.Server.Protocols[store.DNSTTKey].Port = freeUDP(t)
		st.Server.Protocols[store.DNSTTKey].Enabled = true
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if err := srv.Reload(); err != nil {
		t.Fatal(err)
	}
	st, _ := s.Load()
	profiles, err := serverconf.Profiles(st, s, st.User("alice"))
	if err != nil {
		t.Fatalf("the other profiles should still be handed out: %v", err)
	}
	for _, p := range profiles {
		if p.Protocol == profile.DNSTT {
			t.Fatal("a DNS tunnel without a domain has nothing to hand out")
		}
	}
	srv.mu.Lock()
	running := srv.dnstt != nil
	srv.mu.Unlock()
	if running {
		t.Fatal("the DNS tunnel should not start without a domain")
	}
	for _, l := range serverconf.Links(st, s, st.User("alice")) {
		if strings.HasPrefix(l.URL, "dnstt://") {
			t.Fatalf("no link without a domain: %s", l.URL)
		}
	}
}
