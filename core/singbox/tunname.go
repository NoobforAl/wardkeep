package singbox

// WindowsTunName is the name of the TUN adapter on Windows. It is fixed so the
// kill switch can find the adapter and so leftovers of a crashed run can be
// recognised and removed (the adapter's identity is derived from its name).
const WindowsTunName = "Wardkeep"
