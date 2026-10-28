package control

import (
	"context"
	"errors"
	"time"

	"github.com/NoobforAl/omnitun/core/engine"
)

// Methods of the mesh (Tailscale/Headscale) devices screen; they work while a
// mesh profile is connected.
//
//	mesh_status                      -> engine.MeshStatus
//	mesh_exit  {"id": "<device>"}    -> engine.MeshStatus   (empty id: back to the normal connection)
//	mesh_ping  {"address": "100.x"}  -> engine.MeshPing

// MeshExitParams picks the device whose connection is used as the exit.
type MeshExitParams struct {
	ID string `json:"id"`
}

// MeshPingParams names a device by one of its mesh addresses.
type MeshPingParams struct {
	Address string `json:"address"`
}

// dispatchMesh answers the mesh methods; handled is false for any other method.
func (s *Server) dispatchMesh(req Request) (res any, handled bool, err error) {
	switch req.Method {
	case "mesh_status":
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		st, err := s.engine.MeshStatus(ctx)
		return st, true, meshError(err)
	case "mesh_exit":
		params, err := decode[MeshExitParams](req.Params)
		if err != nil {
			return nil, true, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := s.engine.SetMeshExit(ctx, params.ID); err != nil {
			return nil, true, meshError(err)
		}
		st, err := s.engine.MeshStatus(ctx)
		return st, true, meshError(err)
	case "mesh_ping":
		params, err := decode[MeshPingParams](req.Params)
		if err != nil {
			return nil, true, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		r, err := s.engine.PingMeshDevice(ctx, params.Address)
		return r, true, meshError(err)
	}
	return nil, false, nil
}

// meshError maps the engine's mesh errors to protocol errors.
func meshError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, engine.ErrNoMesh):
		return &Error{Code: CodeNotRunning, Message: err.Error()}
	}
	return &Error{Code: CodeMeshFailed, Message: err.Error()}
}
