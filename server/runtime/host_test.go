//go:build with_acme && with_quic && with_utls && with_wireguard && with_gvisor

package runtime

import (
	"net"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/server/manager"
	"github.com/NoobforAl/omnitun/server/store"
)

// recordingRunner stands in for nft/iptables.
type recordingRunner struct {
	mu  sync.Mutex
	ran []string
}

func (r *recordingRunner) Run(argv ...string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.ran = append(r.ran, strings.Join(argv, " "))
	return nil
}
func (r *recordingRunner) Has(name string) bool { return name == "nft" }

// Enabling the DNSCrypt resolver starts its host server; disabling it stops
// the server again.
func TestHostProtocolsFollowTheConfiguration(t *testing.T) {
	s, srv := setup(t)
	srv.runner = &recordingRunner{}

	m := manager.New(s)
	if srv.hosts[store.DNSCryptKey] != nil {
		t.Fatal("DNSCrypt runs although it is off by default")
	}
	if _, err := m.SetDNSCryptListen("127.0.0.1"); err != nil {
		t.Fatal(err)
	}
	port := freeTCP(t)
	on := true
	if _, err := m.SetProtocol(store.DNSCryptKey, manager.ProtocolPatch{Enabled: &on, Port: &port}); err != nil {
		t.Fatal(err)
	}
	if err := srv.Reload(); err != nil {
		t.Fatal(err)
	}
	if srv.hosts[store.DNSCryptKey] == nil {
		t.Fatal("DNSCrypt did not start")
	}
	waitFor(t, "DNSCrypt to listen", 5*time.Second, func() bool {
		c, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)), 200*time.Millisecond)
		if err == nil {
			c.Close()
		}
		return err == nil
	})

	off := false
	if _, err := m.SetProtocol(store.DNSCryptKey, manager.ProtocolPatch{Enabled: &off}); err != nil {
		t.Fatal(err)
	}
	if err := srv.Reload(); err != nil {
		t.Fatal(err)
	}
	if srv.hosts[store.DNSCryptKey] != nil {
		t.Fatal("DNSCrypt still runs after being disabled")
	}
}
