package singbox

// SetMeshSupported lets tests of other packages look at the config a build with
// Tailscale support makes; it returns the function that puts the old value back.
func SetMeshSupported(on bool) (restore func()) {
	was := meshSupported
	meshSupported = on
	return func() { meshSupported = was }
}
