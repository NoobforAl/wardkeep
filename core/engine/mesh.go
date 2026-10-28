package engine

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"sync/atomic"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"

	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/singbox"
)

// ErrNoMesh is returned by the mesh calls when the running tunnel is not a mesh profile.
var ErrNoMesh = errors.New("no mesh (Tailscale/Headscale) profile is connected")

// MeshDevice is one device of the mesh.
type MeshDevice struct {
	// ID is the stable identifier the exit choice uses.
	ID   string `json:"id"`
	Name string `json:"name"`
	// DNSName is the device's MagicDNS name without the final dot ("laptop.tailnet.example").
	DNSName   string   `json:"dns_name,omitempty"`
	OS        string   `json:"os,omitempty"`
	Addresses []string `json:"addresses,omitempty"`
	Online    bool     `json:"online"`
	// ExitOption is set when the device offers its connection as an exit.
	ExitOption bool `json:"exit_option,omitempty"`
	// Exit is set for the device whose connection is in use as the exit.
	Exit bool `json:"exit,omitempty"`
	// LastSeen is a Unix time, 0 when unknown.
	LastSeen int64 `json:"last_seen,omitempty"`
	// Owner names the account the device belongs to (devices shared with you
	// belong to someone else).
	Owner string `json:"owner,omitempty"`
}

// MeshStatus is what the mesh looks like from this device.
type MeshStatus struct {
	// State is Tailscale's own: NoState, NeedsLogin, Starting, Running, Stopped, ...
	State string `json:"state"`
	// AuthURL is set when the device waits for someone to log in (the auth key was not accepted).
	AuthURL string `json:"auth_url,omitempty"`
	// Network is the name of the network, Domain the MagicDNS suffix of its devices.
	Network string      `json:"network,omitempty"`
	Domain  string      `json:"domain,omitempty"`
	Self    *MeshDevice `json:"self,omitempty"`
	// Devices are the other devices, online ones first.
	Devices []MeshDevice `json:"devices"`
}

// MeshPing is the answer to a ping of one device.
type MeshPing struct {
	LatencyMs float64 `json:"latency_ms"`
	// Direct is true when the packets go straight to the device, false through a relay.
	Direct bool `json:"direct"`
	// Path names the endpoint (direct) or the relay region (relayed).
	Path  string `json:"path,omitempty"`
	Error string `json:"error,omitempty"`
}

// selectedMesh returns the selected profile when it is a mesh profile.
func selectedMesh(profiles []*profile.Profile, selected string) *profile.Profile {
	if p := findProfile(profiles, selected); p != nil && p.Protocol == profile.Tailscale {
		return p
	}
	return nil
}

// withoutIdleMesh drops the mesh profiles that are not the selected one: a mesh
// device is online (and costs battery and data) only while it is in use.
func withoutIdleMesh(profiles []*profile.Profile, selected string) []*profile.Profile {
	out := make([]*profile.Profile, 0, len(profiles))
	for _, p := range profiles {
		if p.Protocol != profile.Tailscale || p.ID == selected {
			out = append(out, p)
		}
	}
	return out
}

// meshStateDir is where mesh profiles keep their device identity.
func (e *Engine) meshStateDir() string { return filepath.Join(e.dataDir(), "mesh") }

// meshEndpoint returns the running Tailscale endpoint.
func (e *Engine) meshEndpoint() (*box.Box, adapter.TailscaleEndpoint, string, error) {
	e.mu.Lock()
	instance, id := e.instance, e.meshID
	e.mu.Unlock()
	if instance == nil || id == "" {
		return nil, nil, "", ErrNoMesh
	}
	ep, ok := instance.Endpoint().Get(singbox.MeshEndpointTag(id))
	if !ok {
		return nil, nil, "", ErrNoMesh
	}
	ts, ok := ep.(adapter.TailscaleEndpoint)
	if !ok {
		return nil, nil, "", ErrNoMesh
	}
	return instance, ts, id, nil
}

// MeshStatus reports the devices of the connected mesh.
func (e *Engine) MeshStatus(ctx context.Context) (*MeshStatus, error) {
	_, ts, _, err := e.meshEndpoint()
	if err != nil {
		return nil, err
	}
	// The endpoint pushes its status to a watcher; the first push is the current one.
	wctx, cancel := context.WithCancel(ctx)
	defer cancel()
	got := make(chan *adapter.TailscaleEndpointStatus, 1)
	done := make(chan error, 1)
	go func() {
		done <- ts.SubscribeTailscaleStatus(wctx, func(s *adapter.TailscaleEndpointStatus) {
			select {
			case got <- s:
			default:
			}
		})
	}()
	select {
	case s := <-got:
		return convertMeshStatus(s), nil
	case err := <-done:
		return nil, err
	case <-time.After(5 * time.Second):
		return nil, errors.New("the mesh did not answer")
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func convertMeshStatus(status *adapter.TailscaleEndpointStatus) *MeshStatus {
	out := &MeshStatus{State: status.BackendState, AuthURL: status.AuthURL, Network: status.NetworkName, Domain: status.MagicDNSSuffix, Devices: []MeshDevice{}}
	if status.Self != nil {
		d := convertMeshDevice(status.Self, "")
		out.Self = &d
	}
	for _, group := range status.UserGroups {
		owner := group.DisplayName
		if owner == "" {
			owner = group.LoginName
		}
		for _, p := range group.Peers {
			out.Devices = append(out.Devices, convertMeshDevice(p, owner))
		}
	}
	// Online first, then by name; the order is stable between refreshes.
	slices.SortStableFunc(out.Devices, func(a, b MeshDevice) int {
		if a.Online != b.Online {
			if a.Online {
				return -1
			}
			return 1
		}
		return strings.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name))
	})
	if status.ExitNode != nil {
		for i := range out.Devices {
			if out.Devices[i].ID == status.ExitNode.StableID {
				out.Devices[i].Exit = true
			}
		}
	}
	return out
}

func convertMeshDevice(peer *adapter.TailscalePeer, owner string) MeshDevice {
	return MeshDevice{
		ID: peer.StableID, Name: peer.HostName, DNSName: strings.TrimSuffix(peer.DNSName, "."), OS: peer.OS,
		Addresses: peer.TailscaleIPs, Online: peer.Online, ExitOption: peer.ExitNodeOption, Exit: peer.ExitNode,
		LastSeen: peer.LastSeen, Owner: owner,
	}
}

// SetMeshExit sends all traffic out through the device with the given ID, or
// back to the normal connection when id is empty.
func (e *Engine) SetMeshExit(ctx context.Context, id string) error {
	instance, ts, meshID, err := e.meshEndpoint()
	if err != nil {
		return err
	}
	if err := ts.SetTailscaleExitNode(ctx, id); err != nil {
		return err
	}
	group, ok := instance.Outbound().Outbound(meshID)
	if !ok {
		return fmt.Errorf("mesh selector %q not found", meshID)
	}
	sel, ok := group.(interface{ SelectOutbound(string) bool })
	if !ok {
		return fmt.Errorf("mesh selector %q cannot switch", meshID)
	}
	target := singbox.TagDirect
	if id != "" {
		target = singbox.MeshEndpointTag(meshID)
	}
	if !sel.SelectOutbound(target) {
		return fmt.Errorf("cannot select %q", target)
	}
	if id == "" {
		e.logf("info", "mesh: back to the normal connection")
	} else {
		e.logf("info", "mesh: using a device as the exit")
	}
	return nil
}

// PingMeshDevice pings one device (by a mesh address) once and says whether the
// packets reach it directly or through a relay.
func (e *Engine) PingMeshDevice(ctx context.Context, address string) (*MeshPing, error) {
	_, ts, _, err := e.meshEndpoint()
	if err != nil {
		return nil, err
	}
	pctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	got := make(chan *adapter.TailscalePingResult, 1)
	done := make(chan error, 1)
	go func() {
		done <- ts.StartTailscalePing(pctx, address, func(r *adapter.TailscalePingResult) {
			select {
			case got <- r:
			default:
			}
		})
	}()
	select {
	case r := <-got:
		out := &MeshPing{LatencyMs: r.LatencyMs, Direct: r.IsDirect, Error: r.Error}
		if r.IsDirect {
			out.Path = r.Endpoint
		} else {
			out.Path = firstNonEmpty(r.PeerRelay, r.DERPRegionCode)
		}
		return out, nil
	case err := <-done:
		return nil, err
	case <-pctx.Done():
		return nil, errors.New("no answer from the device")
	}
}

func firstNonEmpty(v ...string) string {
	for _, s := range v {
		if s != "" {
			return s
		}
	}
	return ""
}

// waitMeshRunning waits until the mesh device has joined its network. It is the
// handshake of a mesh profile without an exit: nothing else would tell that the
// auth key was accepted and the control server reached.
func waitMeshRunning(ctx context.Context, ts adapter.TailscaleEndpoint, limit time.Duration) error {
	wctx, cancel := context.WithTimeout(ctx, limit)
	defer cancel()
	var needsLogin atomic.Bool
	running := make(chan struct{})
	var once atomic.Bool
	go func() {
		_ = ts.SubscribeTailscaleStatus(wctx, func(s *adapter.TailscaleEndpointStatus) {
			needsLogin.Store(s.AuthURL != "" || s.BackendState == "NeedsLogin")
			if s.BackendState == "Running" && once.CompareAndSwap(false, true) {
				close(running)
			}
		})
	}()
	select {
	case <-running:
		return nil
	case <-wctx.Done():
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if needsLogin.Load() {
			return errors.New("the control server did not accept the auth key (it may be expired or used up)")
		}
		return errors.New("could not join the network: the control server did not answer in time")
	}
}
