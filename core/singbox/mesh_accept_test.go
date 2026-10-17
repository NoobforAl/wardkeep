package singbox_test

import (
	"testing"

	"github.com/NoobforAl/omnitun/core/engine"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// What Build makes for a mesh profile is accepted by sing-box itself (its option
// parser, with the DNS server and rule types), in proxy and in TUN mode, with and
// without an exit device. (Whether the endpoint can run is up to the build tag.)
func TestMeshConfigIsAcceptedBySingBox(t *testing.T) {
	defer singbox.SetMeshSupported(true)()
	for name, opts := range map[string]*profile.TailscaleOpts{
		"mesh only":      nil,
		"own control":    {},
		"headscale":      {ControlURL: "https://hs.example.com:8443", Hostname: "phone", AcceptRoutes: true, Ephemeral: true},
		"exit device":    {ExitNode: "home-pc"},
		"exit by IP":     {ControlURL: "http://10.0.0.5:8080", ExitNode: "100.64.0.7"},
		"all the extras": {ControlURL: "https://hs.example.com", Hostname: "p", ExitNode: "100.64.0.7", AcceptRoutes: true, Ephemeral: true},
	} {
		for _, mode := range []singbox.Mode{singbox.ModeProxy, singbox.ModeTUN} {
			t.Run(name+"/"+string(mode), func(t *testing.T) {
				p := &profile.Profile{Name: "Home", Protocol: profile.Tailscale, Password: "tskey-auth-kABC-secret", Tailscale: opts}
				p.EnsureID()
				cfg, _, err := singbox.Build([]*profile.Profile{p}, singbox.Options{Mode: mode, Selected: p.ID, StateDir: t.TempDir()})
				if err != nil {
					t.Fatal(err)
				}
				if err := engine.CheckConfig(cfg); err != nil {
					t.Fatalf("sing-box rejects the config: %v", err)
				}
				// The check is real: a field the endpoint does not have is refused.
				cfg["endpoints"].([]any)[0].(map[string]any)["exit_nod"] = "x"
				if err := engine.CheckConfig(cfg); err == nil {
					t.Fatal("an unknown endpoint field was accepted")
				}
			})
		}
	}
}
