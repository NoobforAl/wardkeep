//go:build !with_tailscale

package singbox

// MeshBuilt says whether this build can run mesh (Tailscale/Headscale) profiles:
// it needs sing-box's tailscale endpoint, which is compiled in with the
// with_tailscale build tag (about 11-14 MB more).
const MeshBuilt = false
