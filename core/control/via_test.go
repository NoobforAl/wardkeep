package control

import (
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func TestCheckVia(t *testing.T) {
	wg := func(via string) *profile.Profile {
		return &profile.Profile{Protocol: profile.WireGuard, WireGuard: &profile.WG{Via: via}}
	}
	for _, ok := range []*profile.Profile{
		wg(""),
		wg("  "),
		wg("trojan://pw@proxy.example.com:443?security=tls#p"),
		{Protocol: profile.Trojan},
	} {
		if err := checkVia(ok); err != nil {
			t.Errorf("%+v: %v", ok.WireGuard, err)
		}
	}
	err := checkVia(wg("trojan://"))
	if err == nil || !strings.Contains(err.Error(), "the proxy under WireGuard") {
		t.Errorf("a link with no server should be refused with a clear message, got %v", err)
	}
}
