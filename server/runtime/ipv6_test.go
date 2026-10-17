package runtime

import (
	"net/netip"
	"testing"

	"github.com/NoobforAl/omnitun/server/store"
)

// A WireGuard user is told apart by the tunnel address a connection comes from, by the
// IPv6 one as well, so traffic over IPv6 is counted for the right user.
func TestUserByTunnelIPKnowsBothAddresses(t *testing.T) {
	s := &Server{}
	s.setWireGuardUsers(&store.State{Users: []*store.User{
		{Name: "alice", WGAddress: "10.30.0.2/32"}, {Name: "bob", WGAddress: "10.30.1.2/32"},
	}})
	for addr, want := range map[string]string{
		"10.30.0.2": "alice", "fd30:0:0:1::2": "alice", "10.30.1.2": "bob", "fd30:0:0:1::102": "bob",
		"10.30.0.9": "", "fd30:0:0:1::9": "",
	} {
		if got := s.userByTunnelIP(netip.MustParseAddr(addr)); got != want {
			t.Errorf("userByTunnelIP(%s) = %q, want %q", addr, got, want)
		}
	}
}
