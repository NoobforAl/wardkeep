package mobile

import (
	"context"
	"encoding/json"
	"net"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/engine"
)

func TestStartTunnelFromJSONNeedsTheCore(t *testing.T) {
	mu.Lock()
	saved := srv
	srv = nil
	mu.Unlock()
	defer func() {
		mu.Lock()
		srv = saved
		mu.Unlock()
	}()
	if err := StartTunnelFromJSON(`{"profiles":[]}`); err == nil {
		t.Fatal("started without a running core")
	}
}

func TestRestartTunnelFromJSONNeedsTheCore(t *testing.T) {
	mu.Lock()
	saved := srv
	srv = nil
	mu.Unlock()
	defer func() {
		mu.Lock()
		srv = saved
		mu.Unlock()
	}()
	if err := RestartTunnelFromJSON(`{"profiles":[]}`); err == nil {
		t.Fatal("restarted without a running core")
	}
}

// Reconnect sends the saved request as a "start" whatever is running: the engine replaces a running tunnel
// itself, without a stop that would close the VPN interface in between.
func TestRestartSendsTheSavedStart(t *testing.T) {
	var method, params string
	err := restartWith(func(m string, p json.RawMessage) (any, error) {
		method, params = m, string(p)
		return nil, nil
	}, `{"selected":"p_1"}`)
	if err != nil {
		t.Fatal(err)
	}
	if method != "start" || params != `{"selected":"p_1"}` {
		t.Fatalf("called %q with %s, want start with the saved request", method, params)
	}
	if err := restartWith(func(string, json.RawMessage) (any, error) { return nil, nil }, ""); err == nil {
		t.Fatal("restarted with no saved request")
	}
}

// A second Reconnect while one is in progress does nothing; the next one after it works again.
func TestRestartIgnoresATapWhileReconnecting(t *testing.T) {
	entered, release := make(chan struct{}), make(chan struct{})
	done := make(chan error)
	go func() {
		done <- restartWith(func(string, json.RawMessage) (any, error) {
			close(entered)
			<-release
			return nil, nil
		}, `{}`)
	}()
	<-entered
	calls := 0
	count := func(string, json.RawMessage) (any, error) { calls++; return nil, nil }
	if err := restartWith(count, `{}`); err != nil || calls != 0 {
		t.Fatalf("second restart: err %v, %d calls; want ignored", err, calls)
	}
	close(release)
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if err := restartWith(count, `{}`); err != nil || calls != 1 {
		t.Fatalf("restart after the first ended: err %v, %d calls; want 1", err, calls)
	}
}

// The notification shows why a connection failed; the reason never carries an address.
func TestNotifyStateErrorIsScrubbed(t *testing.T) {
	got := newNotifyState(engine.State{
		Status: engine.StatusError, ProfileName: "Home",
		Error: "Handshake failed: dial tcp 192.0.2.7:443: i/o timeout", ErrorCode: engine.ErrTimeout,
	})
	if got.Status != "error" || got.ErrorCode != engine.ErrTimeout || got.Profile != "Home" {
		t.Fatalf("notifyState = %+v", got)
	}
	if strings.Contains(got.Error, "192.0.2.7") || !strings.Contains(got.Error, "i/o timeout") {
		t.Fatalf("error %q: want the reason without the address", got.Error)
	}
	running := newNotifyState(engine.State{Status: engine.StatusRunning, Error: "stale", ErrorCode: "X"})
	if running.Error != "" || running.ErrorCode != "" {
		t.Fatalf("a running state carries an error: %+v", running)
	}
}

// fakePlatform answers only Interfaces; the embedded nil interface covers the rest.
type fakePlatform struct {
	Platform
	interfaces string
	protected  *int
}

func (f fakePlatform) Protect(int32) error {
	if f.protected != nil {
		*f.protected++
	}
	return nil
}

func (f fakePlatform) Interfaces() (string, error) { return f.interfaces, nil }

// Go cannot read a phone's resolvers itself, so they come from the platform's network list:
// the usable ones of real, up networks, IPv4 first, never loopback or link-local.
func TestSystemDNSFromThePlatformNetworks(t *testing.T) {
	w := newPlatformWrapper(fakePlatform{interfaces: `[
		{"name":"lo","index":1,"flags":73,"type":"other","dns":["127.0.0.1"]},
		{"name":"tun0","index":9,"flags":65,"type":"other","dns":["10.0.0.2"]},
		{"name":"wlan0","index":3,"flags":65,"type":"wifi","dns":["fe80::1","2001:db8::53","5.200.200.200","0.0.0.0","8.8.8.8"]}
	]`})
	got := w.SystemDNS()
	want := []string{"5.200.200.200", "8.8.8.8", "2001:db8::53"}
	if len(got) != len(want) {
		t.Fatalf("SystemDNS = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("SystemDNS = %v, want %v", got, want)
		}
	}
}

// Go's own resolver would ask [::1]:53 on Android. The installed one asks the network's
// resolver, over a socket the VPN does not capture.
func TestInstalledResolverUsesProtectedSockets(t *testing.T) {
	saved := net.DefaultResolver
	defer func() { net.DefaultResolver = saved }()
	protected := 0
	installResolver(newPlatformWrapper(fakePlatform{
		interfaces: `[{"name":"wlan0","index":3,"flags":65,"type":"wifi","dns":["192.0.2.53"]}]`,
		protected:  &protected,
	}))
	conn, err := net.DefaultResolver.Dial(context.Background(), "udp", "[::1]:53")
	if err == nil {
		defer conn.Close()
		if got := conn.RemoteAddr().String(); got != "192.0.2.53:53" {
			t.Errorf("dialed %s, want the network's resolver 192.0.2.53:53", got)
		}
	}
	if protected != 1 {
		t.Errorf("the DNS socket was protected %d times, want 1", protected)
	}
}
