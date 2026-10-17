package engine

import (
	"context"
	"errors"
	"testing"

	"github.com/sagernet/sing-box/adapter"

	"github.com/NoobforAl/omnitun/core/profile"
)

func TestMeshCallsNeedAMeshTunnel(t *testing.T) {
	e := New(Config{})
	if _, err := e.MeshStatus(context.Background()); !errors.Is(err, ErrNoMesh) {
		t.Errorf("status: %v", err)
	}
	if err := e.SetMeshExit(context.Background(), "x"); !errors.Is(err, ErrNoMesh) {
		t.Errorf("exit: %v", err)
	}
	if _, err := e.PingMeshDevice(context.Background(), "100.64.0.1"); !errors.Is(err, ErrNoMesh) {
		t.Errorf("ping: %v", err)
	}
}

func TestMeshProfilesRunOnlyWhenSelected(t *testing.T) {
	mesh := &profile.Profile{ID: "m", Protocol: profile.Tailscale}
	other := &profile.Profile{ID: "o", Protocol: profile.Trojan}
	if got := withoutIdleMesh([]*profile.Profile{mesh, other}, "auto"); len(got) != 1 || got[0] != other {
		t.Errorf("auto: %v", got)
	}
	if got := withoutIdleMesh([]*profile.Profile{mesh, other}, "m"); len(got) != 2 {
		t.Errorf("selected: %v", got)
	}
	if selectedMesh([]*profile.Profile{mesh, other}, "o") != nil || selectedMesh([]*profile.Profile{mesh, other}, "m") != mesh {
		t.Error("selectedMesh")
	}
}

func TestConvertMeshStatus(t *testing.T) {
	st := convertMeshStatus(&adapter.TailscaleEndpointStatus{
		BackendState: "Running", NetworkName: "home.example", MagicDNSSuffix: "ts.example",
		Self: &adapter.TailscalePeer{StableID: "s", HostName: "phone", DNSName: "phone.ts.example.", TailscaleIPs: []string{"100.64.0.2"}, Online: true},
		UserGroups: []*adapter.TailscaleUserGroup{
			{DisplayName: "Alice", Peers: []*adapter.TailscalePeer{
				{StableID: "b", HostName: "Zeta", DNSName: "zeta.ts.example.", Online: false, LastSeen: 100},
				{StableID: "a", HostName: "home-pc", DNSName: "home-pc.ts.example.", TailscaleIPs: []string{"100.64.0.1", "fd7a::1"}, Online: true, ExitNodeOption: true, OS: "windows"},
				{StableID: "c", HostName: "alpha", Online: true},
			}},
			{LoginName: "bob@example.com", Peers: []*adapter.TailscalePeer{{StableID: "d", HostName: "shared", Online: true}}},
		},
		ExitNode: &adapter.TailscalePeer{StableID: "a"},
	})
	if st.State != "Running" || st.Network != "home.example" || st.Domain != "ts.example" || st.Self.DNSName != "phone.ts.example" {
		t.Fatalf("status = %+v", st)
	}
	// Online devices first, by name; offline ones last.
	var names []string
	for _, d := range st.Devices {
		names = append(names, d.Name)
	}
	want := []string{"alpha", "home-pc", "shared", "Zeta"}
	if len(names) != len(want) {
		t.Fatalf("devices = %v", names)
	}
	for i := range want {
		if names[i] != want[i] {
			t.Fatalf("devices = %v, want %v", names, want)
		}
	}
	home := st.Devices[1]
	if !home.Exit || !home.ExitOption || home.DNSName != "home-pc.ts.example" || home.Owner != "Alice" || len(home.Addresses) != 2 || home.OS != "windows" {
		t.Errorf("home-pc = %+v", home)
	}
	if st.Devices[2].Owner != "bob@example.com" || st.Devices[0].Exit {
		t.Errorf("devices = %+v", st.Devices)
	}
	if got := convertMeshStatus(&adapter.TailscaleEndpointStatus{}); got.Devices == nil {
		t.Error("an empty mesh must list no devices, not null")
	}
}
