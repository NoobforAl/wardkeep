package control

import (
	"errors"
	"testing"

	"github.com/NoobforAl/omnitun/core/engine"
)

// Every mesh call refuses politely when no mesh profile is connected.
func TestMeshCallsNeedAMeshTunnel(t *testing.T) {
	s, addr := newTestServer(t, ServerConfig{})
	c, err := Dial(t.Context(), addr, s.Token())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	for method, params := range map[string]any{
		"mesh_status": nil,
		"mesh_exit":   MeshExitParams{ID: "x"},
		"mesh_ping":   MeshPingParams{Address: "100.64.0.1"},
	} {
		var out any
		err := c.Call(t.Context(), method, params, &out)
		var ce *Error
		if !errors.As(err, &ce) || ce.Code != CodeNotRunning {
			t.Errorf("%s: err = %v, want NOT_RUNNING", method, err)
		}
	}
	var st engine.MeshStatus
	if err := c.Call(t.Context(), "mesh_status", nil, &st); err == nil {
		t.Error("a status without a mesh")
	}
}
