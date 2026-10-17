//go:build !with_tailscale

package engine

import (
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// Without the with_tailscale tag a mesh profile cannot run, and says why.
func TestMeshProfileNeedsTheTag(t *testing.T) {
	mesh := &profile.Profile{Name: "Lab", Protocol: profile.Tailscale, Password: "k"}
	mesh.EnsureID()
	e := New(Config{DataDir: tempDir(t), SkipHandshake: true})
	err := e.Start(mesh.AsSlice(), singbox.Options{Selected: mesh.ID})
	if err == nil || !strings.Contains(err.Error(), "with_tailscale") {
		t.Fatalf("err = %v", err)
	}
	if s := e.State(); s.Status != StatusError || !strings.Contains(s.Error, "with_tailscale") {
		t.Fatalf("state = %+v", s)
	}
}
