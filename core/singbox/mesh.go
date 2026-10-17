package singbox

import (
	"errors"
	"path/filepath"

	"github.com/NoobforAl/omnitun/core/profile"
)

// ErrMeshNotBuilt is returned when a mesh profile is selected in a build that
// has no Tailscale support (see MeshBuilt).
var ErrMeshNotBuilt = errors.New("this build of the core has no support for Tailscale/Headscale profiles (it needs the with_tailscale build tag)")

// meshSupported is MeshBuilt; tests change it to look at the config a build
// with Tailscale support makes.
var meshSupported = MeshBuilt

// MeshEndpointTag is the tag of the Tailscale endpoint that belongs to the
// profile with the given ID. The profile's own ID tags a selector in front of
// it (see meshProfile).
func MeshEndpointTag(id string) string { return id + "-ts" }

// meshDNSTag names the DNS server that answers the mesh's own names (MagicDNS).
const meshDNSTag = "mesh-dns"

// meshProfile converts a mesh profile into the Tailscale endpoint and a
// selector that carries the profile's ID:
//
//   - with an exit device in the profile, the selector points at the endpoint, so
//     all traffic leaves through that device;
//   - without one, it points at "direct": only the mesh's own addresses and names
//     (matched by the preferred_by rule applyMesh adds) use the endpoint, and
//     everything else keeps using the normal connection. The exit can be chosen
//     later, while connected (Engine.SetMeshExit).
//
// stateDir is where Tailscale keeps this device's identity; it is kept per
// profile, so reconnecting does not register a new device each time.
func meshProfile(p *profile.Profile, stateDir string) (endpoint obj, group obj) {
	o := p.Tailscale
	if o == nil {
		o = &profile.TailscaleOpts{}
	}
	ep := obj{
		"type":      "tailscale",
		"tag":       MeshEndpointTag(p.ID),
		"auth_key":  p.Password,
		"ephemeral": o.Ephemeral,
	}
	if stateDir != "" {
		ep["state_directory"] = filepath.Join(stateDir, p.ID)
	} else {
		ep["state_directory"] = "tailscale-" + p.ID
	}
	if o.ControlURL != "" {
		ep["control_url"] = o.ControlURL
	}
	if o.Hostname != "" {
		ep["hostname"] = o.Hostname
	}
	if o.ExitNode != "" {
		ep["exit_node"] = o.ExitNode
	}
	if o.AcceptRoutes {
		ep["accept_routes"] = true
	}
	def := TagDirect
	if o.ExitNode != "" {
		def = MeshEndpointTag(p.ID)
	}
	group = obj{
		"type":      "selector",
		"tag":       p.ID,
		"outbounds": []string{MeshEndpointTag(p.ID), TagDirect},
		"default":   def,
	}
	return ep, group
}

// applyMesh adds what makes the mesh's addresses and names reach the endpoint
// whatever the selected outbound is: a route rule (the endpoint's own
// preferred routes: its peers' addresses, the subnets it accepted, MagicDNS
// names) and a DNS server for the MagicDNS names.
func applyMesh(cfg obj, endpoints []string) {
	if len(endpoints) == 0 {
		return
	}
	route := cfg["route"].(obj)
	rules := route["rules"].([]any)
	meshRule := obj{"preferred_by": endpoints, "action": "route", "outbound": endpoints[0]}
	// After the DNS hijack (rule 0), before anything that sends addresses elsewhere.
	route["rules"] = append([]any{rules[0], meshRule}, rules[1:]...)

	dns := cfg["dns"].(obj)
	dns["servers"] = append(dns["servers"].([]any), obj{"type": "tailscale", "tag": meshDNSTag, "endpoint": endpoints[0]})
	// In a DNS rule, preferred_by names the DNS server (whose endpoint knows the MagicDNS domains).
	dnsRule := obj{"preferred_by": []string{meshDNSTag}, "action": "route", "server": meshDNSTag}
	existing, _ := dns["rules"].([]any)
	dns["rules"] = append([]any{dnsRule}, existing...)
}
