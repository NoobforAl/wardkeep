package singbox

import (
	"errors"
	"path/filepath"
	"slices"
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func meshProfileFor(t *testing.T, o *profile.TailscaleOpts) *profile.Profile {
	t.Helper()
	p := &profile.Profile{Name: "Home", Protocol: profile.Tailscale, Password: "tskey-auth-kABC-secret", Tailscale: o}
	p.EnsureID()
	return p
}

func find(items any, tag string) obj {
	for _, x := range items.([]any) {
		if m, ok := x.(obj); ok && m["tag"] == tag {
			return m
		}
	}
	return nil
}

func TestMeshProfileMakesAnEndpointAndASelector(t *testing.T) {
	meshSupported = true
	defer func() { meshSupported = MeshBuilt }()
	mesh := meshProfileFor(t, &profile.TailscaleOpts{ControlURL: "https://hs.example.com", Hostname: "phone", AcceptRoutes: true, Ephemeral: true})
	other := &profile.Profile{Name: "x", Protocol: profile.Trojan, Server: "203.0.113.7", Port: 443, Password: "pw"}
	other.EnsureID()

	cfg, skipped, err := Build([]*profile.Profile{other, mesh}, Options{Selected: mesh.ID, StateDir: "/data/mesh"})
	if err != nil || len(skipped) != 0 {
		t.Fatalf("err=%v skipped=%v", err, skipped)
	}
	ep := find(cfg["endpoints"], MeshEndpointTag(mesh.ID))
	if ep == nil {
		t.Fatalf("no endpoint in %v", cfg["endpoints"])
	}
	if ep["type"] != "tailscale" || ep["auth_key"] != "tskey-auth-kABC-secret" || ep["control_url"] != "https://hs.example.com" ||
		ep["hostname"] != "phone" || ep["accept_routes"] != true || ep["ephemeral"] != true {
		t.Errorf("endpoint = %v", ep)
	}
	if _, has := ep["exit_node"]; has {
		t.Error("an exit node nobody asked for")
	}
	if dir, _ := ep["state_directory"].(string); dir != filepath.Join("/data/mesh", mesh.ID) {
		t.Errorf("state directory = %q", dir)
	}
	// The profile's ID is a selector: with no exit device it keeps the normal connection.
	group := find(cfg["outbounds"], mesh.ID)
	if group["type"] != "selector" || group["default"] != TagDirect || !slices.Equal(group["outbounds"].([]string), []string{MeshEndpointTag(mesh.ID), TagDirect}) {
		t.Errorf("selector = %v", group)
	}
	// The mesh's own addresses and names reach the endpoint in any case, ahead of the other rules.
	rules := cfg["route"].(obj)["rules"].([]any)
	if r := rules[1].(obj); !slices.Equal(r["preferred_by"].([]string), []string{MeshEndpointTag(mesh.ID)}) || r["outbound"] != MeshEndpointTag(mesh.ID) {
		t.Errorf("route rule = %v", rules[1])
	}
	dns := cfg["dns"].(obj)
	if s := find(dns["servers"], meshDNSTag); s == nil || s["type"] != "tailscale" || s["endpoint"] != MeshEndpointTag(mesh.ID) {
		t.Errorf("dns servers = %v", dns["servers"])
	}
	if r := dns["rules"].([]any)[0].(obj); r["server"] != meshDNSTag || !slices.Equal(r["preferred_by"].([]string), []string{meshDNSTag}) {
		t.Errorf("dns rule = %v", r)
	}
	// The other profile is still in the list the selector offers.
	if !slices.Contains(find(cfg["outbounds"], TagSelect)["outbounds"].([]string), other.ID) {
		t.Error("the other profile vanished")
	}
}

func TestMeshExitDeviceIsTheDefaultRoute(t *testing.T) {
	meshSupported = true
	defer func() { meshSupported = MeshBuilt }()
	mesh := meshProfileFor(t, &profile.TailscaleOpts{ExitNode: "home-pc"})
	cfg, _, err := Build([]*profile.Profile{mesh}, Options{Selected: mesh.ID})
	if err != nil {
		t.Fatal(err)
	}
	if ep := find(cfg["endpoints"], MeshEndpointTag(mesh.ID)); ep["exit_node"] != "home-pc" {
		t.Errorf("endpoint = %v", ep)
	}
	if group := find(cfg["outbounds"], mesh.ID); group["default"] != MeshEndpointTag(mesh.ID) {
		t.Errorf("selector = %v", group)
	}
}

// A mesh device is online only while its profile is selected; the others cost nothing.
func TestMeshProfileIsIdleUnlessSelected(t *testing.T) {
	meshSupported = true
	defer func() { meshSupported = MeshBuilt }()
	mesh := meshProfileFor(t, nil)
	other := &profile.Profile{Name: "x", Protocol: profile.Trojan, Server: "203.0.113.7", Port: 443, Password: "pw"}
	other.EnsureID()
	for _, sel := range []string{"", TagAuto, other.ID} {
		cfg, _, err := Build([]*profile.Profile{mesh, other}, Options{Selected: sel})
		if err != nil {
			t.Fatal(err)
		}
		if _, has := cfg["endpoints"]; has {
			t.Errorf("selected %q: endpoints %v", sel, cfg["endpoints"])
		}
		if dns := cfg["dns"].(obj); len(dns["servers"].([]any)) != 2 {
			t.Errorf("selected %q: dns servers %v", sel, dns["servers"])
		}
	}
	if _, _, err := Build([]*profile.Profile{mesh}, Options{}); err == nil {
		t.Error("a list of only an idle mesh profile has nothing to run")
	}
}

func TestMeshNeedsABuildWithTailscale(t *testing.T) {
	was := meshSupported
	meshSupported = false
	defer func() { meshSupported = was }()
	mesh := meshProfileFor(t, nil)
	if _, _, err := Build([]*profile.Profile{mesh}, Options{Selected: mesh.ID}); !errors.Is(err, ErrMeshNotBuilt) {
		t.Fatalf("err = %v", err)
	}
}

func TestMeshWorksInTUNMode(t *testing.T) {
	meshSupported = true
	defer func() { meshSupported = MeshBuilt }()
	mesh := meshProfileFor(t, &profile.TailscaleOpts{ExitNode: "home-pc"})
	cfg, _, err := Build([]*profile.Profile{mesh}, Options{Mode: ModeTUN, Selected: mesh.ID})
	if err != nil {
		t.Fatal(err)
	}
	// The mesh's range (CGNAT, 100.64.0.0/10) must not be among the ranges that bypass the VPN.
	tun := cfg["inbounds"].([]any)[0].(obj)
	for _, c := range tun["route_exclude_address"].([]string) {
		if c == "100.64.0.0/10" {
			t.Errorf("the mesh range is excluded from the tunnel: %v", tun["route_exclude_address"])
		}
	}
}
