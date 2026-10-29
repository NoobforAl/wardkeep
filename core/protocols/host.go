package protocols

// PortUse is one port a protocol listens on.
type PortUse struct {
	Port  int
	Proto string // "tcp" or "udp"
}

// hostBase is shared by the protocols served by a process-level server (a
// TUN device on the host plus NAT) instead of by sing-box.
type hostBase struct{}

// Inbounds is empty: sing-box serves nothing for these protocols.
func (hostBase) Inbounds(Env, int, []Account) Config { return Config{} }
