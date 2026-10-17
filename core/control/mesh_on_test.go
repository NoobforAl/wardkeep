//go:build with_tailscale && with_quic && with_utls && with_wireguard && with_gvisor

package control

import (
	"errors"
	"strconv"
	"testing"

	"github.com/NoobforAl/omnitun/core/engine"
	"github.com/NoobforAl/omnitun/core/importer"
)

// A mesh profile started through the control protocol answers the mesh calls.
// Its control server does not exist, so the device never joins, but the status
// call works and an exit that is not there is refused with MESH_FAILED.
func TestMeshCallsThroughTheControlProtocol(t *testing.T) {
	s, addr := newTestServer(t, ServerConfig{})
	c, err := Dial(t.Context(), addr, s.Token())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	res, err := importer.ParseLink("tailscale://tskey-auth-kABC-secret@127.0.0.1:" + strconv.Itoa(freePort(t)) + "?scheme=http&hostname=wk-ctl#Lab")
	if err != nil {
		t.Fatal(err)
	}
	start := StartParams{Profiles: res.AsSlice(), Selected: res.ID, ListenPort: freePort(t)}
	if err := c.Call(t.Context(), "start", start, nil); err != nil {
		t.Fatal(err)
	}
	defer c.Call(t.Context(), "stop", nil, nil)

	var st engine.MeshStatus
	if err := c.Call(t.Context(), "mesh_status", nil, &st); err != nil {
		t.Fatal(err)
	}
	if st.State == "Running" || st.Devices == nil {
		t.Errorf("status = %+v", st)
	}
	err = c.Call(t.Context(), "mesh_exit", MeshExitParams{ID: "no-such-device"}, nil)
	var ce *Error
	if !errors.As(err, &ce) || ce.Code != CodeMeshFailed {
		t.Errorf("exit: %v, want MESH_FAILED", err)
	}
}
