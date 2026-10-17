package singbox

import (
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func tunInbound(t *testing.T, opts Options) map[string]any {
	t.Helper()
	p := &profile.Profile{Name: "t", Protocol: profile.Trojan, Server: "203.0.113.5", Port: 443, Password: "x"}
	cfg, _, err := Build([]*profile.Profile{p}, opts)
	if err != nil {
		t.Fatal(err)
	}
	for _, in := range cfg["inbounds"].([]any) {
		if m := in.(obj); m["type"] == "tun" {
			return m
		}
	}
	t.Fatal("no tun inbound")
	return nil
}

func TestTunNameIsSetWhenGiven(t *testing.T) {
	if got := tunInbound(t, Options{Mode: ModeTUN, TunName: WindowsTunName})["interface_name"]; got != WindowsTunName {
		t.Errorf("interface_name = %v, want %s", got, WindowsTunName)
	}
}

func TestTunNameIsLeftToSingBoxByDefault(t *testing.T) {
	if _, ok := tunInbound(t, Options{Mode: ModeTUN})["interface_name"]; ok {
		t.Error("interface_name must not be set without TunName")
	}
}

// The kill switch is the control server's business: it must not change the config.
func TestKillSwitchDoesNotChangeTheConfig(t *testing.T) {
	a := tunInbound(t, Options{Mode: ModeTUN})
	b := tunInbound(t, Options{Mode: ModeTUN, KillSwitch: true, KillSwitchEarly: true})
	if len(a) != len(b) {
		t.Errorf("config differs: %v vs %v", a, b)
	}
}
