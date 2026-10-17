//go:build with_tailscale && with_quic && with_utls && with_wireguard && with_gvisor

package engine

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/sagernet/sing-box/adapter"

	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// With Tailscale compiled in, a mesh profile starts a real Tailscale node inside
// the engine; its control server here does not exist, so the node never joins,
// but everything the engine does around it can be checked: the node is created
// with its own state folder, the status call answers, the exit cannot be set to
// a device that is not there, and stopping removes the node.
func TestMeshProfileStartsATailscaleNode(t *testing.T) {
	if !singbox.MeshBuilt {
		t.Fatal("built with the tag but MeshBuilt is false")
	}
	mesh := &profile.Profile{Name: "Lab", Protocol: profile.Tailscale, Password: "tskey-auth-kABC-secret",
		Tailscale: &profile.TailscaleOpts{ControlURL: "http://127.0.0.1:" + itoa(freePort(t)), Hostname: "wk-test"}}
	mesh.EnsureID()
	other := &profile.Profile{Name: "x", Protocol: profile.Trojan, Server: "203.0.113.7", Port: 443, Password: "pw"}
	other.EnsureID()

	dir := tempDir(t)
	e := New(Config{DataDir: dir, SkipHandshake: true})
	if err := e.Start([]*profile.Profile{other, mesh}, singbox.Options{ListenPort: freePort(t), LogLevel: "error", Selected: mesh.ID}); err != nil {
		t.Fatal(err)
	}
	defer e.Stop()

	instance, ts, id, err := e.meshEndpoint()
	if err != nil || id != mesh.ID {
		t.Fatalf("endpoint: id=%q err=%v", id, err)
	}
	var _ adapter.TailscaleEndpoint = ts
	if _, ok := instance.Outbound().Outbound(mesh.ID); !ok {
		t.Error("the mesh selector is missing")
	}
	if fi, err := os.Stat(filepath.Join(dir, "mesh", mesh.ID)); err != nil || !fi.IsDir() {
		t.Errorf("state folder: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	st, err := e.MeshStatus(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if st.State == "Running" || len(st.Devices) != 0 {
		t.Errorf("a node with no control server must not be running: %+v", st)
	}
	if err := e.SetMeshExit(ctx, "no-such-device"); err == nil {
		t.Error("an exit that does not exist was accepted")
	}

	// Switching to a profile that is not a mesh one takes the node away.
	if err := e.Select(other.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := e.MeshStatus(ctx); err == nil {
		t.Error("the mesh node is still there after switching away")
	}
}
