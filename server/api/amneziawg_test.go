package api

import (
	"encoding/json"
	"testing"

	"github.com/NoobforAl/omnitun/server/manager"
)

// The web API lists the AmneziaWG version and changes it with the same patch
// that enables a protocol.
func TestAPIChoosesTheAmneziaWGVersion(t *testing.T) {
	c := newClient(t)
	var protos []manager.ProtocolInfo
	json.Unmarshal(c.ok("GET", "/api/v1/protocols", nil, 200), &protos)
	for _, p := range protos {
		if (p.Key == "amneziawg") != (p.AmneziaWGVersion != "") {
			t.Fatalf("%s reports AmneziaWG version %q", p.Key, p.AmneziaWGVersion)
		}
		if p.Key == "amneziawg" && p.AmneziaWGVersion != "2.0" {
			t.Fatalf("a new server has AmneziaWG %s", p.AmneziaWGVersion)
		}
	}
	var p manager.ProtocolInfo
	json.Unmarshal(c.ok("PATCH", "/api/v1/protocols/amneziawg", map[string]any{"amneziawg_version": "1.x"}, 200), &p)
	if p.AmneziaWGVersion != "1.x" {
		t.Fatalf("patched = %+v", p)
	}
	json.Unmarshal(c.ok("PATCH", "/api/v1/protocols/amneziawg", map[string]any{"amneziawg_version": "2.0"}, 200), &p)
	if p.AmneziaWGVersion != "2.0" {
		t.Fatalf("patched back = %+v", p)
	}
	if status, _ := c.do("PATCH", "/api/v1/protocols/amneziawg", map[string]any{"amneziawg_version": "9.9"}, "Bearer "+token); status != 422 && status != 400 {
		t.Errorf("a wrong version = %d, want 422 or 400", status)
	}
	if status, _ := c.do("PATCH", "/api/v1/protocols/trojan", map[string]any{"amneziawg_version": "2.0"}, "Bearer "+token); status != 400 && status != 422 {
		t.Errorf("a version for trojan = %d, want 400 or 422", status)
	}
}

// The web API reports IPv6 in the tunnels and switches it.
func TestAPISwitchesIPv6(t *testing.T) {
	c := newClient(t)
	var info manager.ServerInfo
	json.Unmarshal(c.ok("GET", "/api/v1/server", nil, 200), &info)
	if info.IPv6 {
		t.Fatal("a new server has IPv6 on")
	}
	json.Unmarshal(c.ok("PUT", "/api/v1/server/ipv6", map[string]any{"enabled": true}, 200), &info)
	if !info.IPv6 {
		t.Fatalf("on: %+v", info)
	}
	json.Unmarshal(c.ok("GET", "/api/v1/server", nil, 200), &info)
	if !info.IPv6 {
		t.Fatal("the setting was not kept")
	}
	if status, _ := c.do("PUT", "/api/v1/server/ipv6", map[string]any{"enabled": false}, ""); status != 401 {
		t.Errorf("without a token = %d, want 401", status)
	}
	json.Unmarshal(c.ok("PUT", "/api/v1/server/ipv6", map[string]any{"enabled": false}, 200), &info)
	if info.IPv6 {
		t.Fatalf("off: %+v", info)
	}
}
