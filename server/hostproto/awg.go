package hostproto

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/amnezia-vpn/amneziawg-go/conn"
	"github.com/amnezia-vpn/amneziawg-go/device"
	"github.com/amnezia-vpn/amneziawg-go/tun"

	"github.com/NoobforAl/omnitun/core/awg"
	"github.com/NoobforAl/omnitun/core/protocols"
)

const (
	awgInterface = "omnitun-awg"
	awgMTU       = 1380
)

// awgParamKeys are the obfuscation parameters every AmneziaWG server has, in the
// order UAPI wants them; awgOptionalKeys are the AmneziaWG 2.0 additions (random
// prefixes on cookie and data packets), used when the server's parameters have
// them. In 2.0 the headers h1-h4 may be ranges such as "100-200".
var (
	awgParamKeys    = []string{"jc", "jmin", "jmax", "s1", "s2", "h1", "h2", "h3", "h4"}
	awgOptionalKeys = []string{"s3", "s4"}
)

// openTUN creates the kernel TUN device; tests replace it.
var openTUN = func(name string, mtu int) (tun.Device, error) { return tun.CreateTUN(name, mtu) }

type awgServer struct {
	dev *device.Device
	r   Runner
	// users names the owner of each peer, by the peer's public key in hex.
	users map[string]string
	// ipv6 is true when users also have an IPv6 address in the tunnel.
	ipv6 bool
}

// awgSessionLife is how long after its last handshake a peer counts as
// connected (WireGuard stops using a session after 180 seconds).
const awgSessionLife = 180 * time.Second

// Usage reads each peer's counters from the device. The peers are fixed, so
// the numbers only grow while the server runs.
func (x awgServer) Usage() []Usage {
	raw, err := x.dev.IpcGet()
	if err != nil {
		return nil
	}
	var out []Usage
	cur := -1
	for line := range strings.SplitSeq(raw, "\n") {
		k, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		switch k {
		case "public_key":
			out = append(out, Usage{User: x.users[value]})
			cur = len(out) - 1
		case "rx_bytes":
			if cur >= 0 {
				out[cur].Up, _ = strconv.ParseUint(value, 10, 64)
			}
		case "tx_bytes":
			if cur >= 0 {
				out[cur].Down, _ = strconv.ParseUint(value, 10, 64)
			}
		case "last_handshake_time_sec":
			// WireGuard has no sessions; a peer that shook hands within the
			// last session lifetime is the closest thing to "connected".
			if at, _ := strconv.ParseInt(value, 10, 64); cur >= 0 && at > 0 && time.Since(time.Unix(at, 0)) < awgSessionLife {
				out[cur].Sessions = 1
			}
		}
	}
	kept := out[:0]
	for _, u := range out {
		if u.User != "" {
			kept = append(kept, u)
		}
	}
	return kept
}

func (x awgServer) Close() error {
	x.dev.Close() // also closes the TUN device, which removes the interface
	return nil
}

func (awgServer) Pool() string { return protocols.AWGPool }

// Pool6 is the tunnel's IPv6 network, or "" when the server has none.
func (x awgServer) Pool6() string {
	if x.ipv6 {
		return protocols.AWGPool6
	}
	return ""
}

func hexKey(b64 string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(b64))
	if err != nil || len(raw) != 32 {
		return "", fmt.Errorf("invalid key")
	}
	return hex.EncodeToString(raw), nil
}

// awgUAPI is the device configuration: the server key, the obfuscation
// parameters and one peer per user (their WireGuard key, an address in the
// AmneziaWG network).
func awgUAPI(cfg Config) (string, map[string]string, error) {
	awgEnv := cfg.Env.AWG
	priv, err := hexKey(awgEnv.PrivateKey)
	if err != nil {
		return "", nil, fmt.Errorf("amneziawg: server private key: %w", err)
	}
	var uapi strings.Builder
	fmt.Fprintf(&uapi, "private_key=%s\nlisten_port=%d\n", priv, cfg.Port)
	for _, k := range awgParamKeys {
		if _, ok := awgEnv.Params[k]; !ok {
			return "", nil, fmt.Errorf("amneziawg: parameter %s is missing", k)
		}
	}
	if err := awg.CheckParams(awgEnv.Params); err != nil {
		return "", nil, fmt.Errorf("amneziawg: %w", err)
	}
	for _, k := range append(append([]string{}, awgParamKeys...), awgOptionalKeys...) {
		if v, ok := awgEnv.Params[k]; ok {
			fmt.Fprintf(&uapi, "%s=%s\n", k, strings.TrimSpace(v))
		}
	}
	uapi.WriteString("replace_peers=true\n")
	peers := 0
	owners := map[string]string{}
	for _, user := range cfg.Users {
		if user.WGPublicKey == "" || user.WGAddress == "" {
			continue
		}
		pub, err := hexKey(user.WGPublicKey)
		if err != nil {
			return "", nil, fmt.Errorf("amneziawg: user %s: public key: %w", user.Name, err)
		}
		addr, err := protocols.AWGAddress(user.WGAddress)
		if err != nil {
			return "", nil, fmt.Errorf("amneziawg: user %s: %w", user.Name, err)
		}
		fmt.Fprintf(&uapi, "public_key=%s\nreplace_allowed_ips=true\nallowed_ip=%s\n", pub, addr)
		if cfg.Env.IPv6 {
			a6, err := protocols.AWGAddress6(user.WGAddress)
			if err != nil {
				return "", nil, fmt.Errorf("amneziawg: user %s: %w", user.Name, err)
			}
			fmt.Fprintf(&uapi, "allowed_ip=%s\n", a6)
		}
		owners[pub] = user.Name
		peers++
	}
	if peers == 0 {
		return "", nil, fmt.Errorf("amneziawg: no user has a WireGuard key")
	}
	return uapi.String(), owners, nil
}

func startAWG(cfg Config) (Server, error) {
	uapi, owners, err := awgUAPI(cfg)
	if err != nil {
		return nil, err
	}
	runner := cfg.Runner
	if runner == nil {
		runner = ExecRunner{}
	}
	tunDev, err := openTUN(awgInterface, awgMTU)
	if err != nil {
		return nil, fmt.Errorf("amneziawg: open TUN device: %w", err)
	}
	logger := &device.Logger{Verbosef: func(string, ...any) {}, Errorf: func(f string, args ...any) {
		if cfg.Logf != nil {
			cfg.Logf("amneziawg: "+f, args...)
		}
	}}
	dev := device.NewDevice(tunDev, conn.NewDefaultBind(), logger)
	fail := func(err error) (Server, error) { dev.Close(); return nil, err }
	if err := dev.IpcSet(uapi); err != nil {
		return fail(fmt.Errorf("amneziawg: configure: %w", err))
	}
	if err := dev.Up(); err != nil {
		return fail(fmt.Errorf("amneziawg: bring up: %w", err))
	}
	name := awgInterface
	if n, err := tunDev.Name(); err == nil && n != "" {
		name = n
	}
	// The kernel interface needs the server's address and to be up.
	if err := runner.Run("ip", "addr", "add", protocols.AWGServerAddress(), "dev", name); err != nil {
		return fail(fmt.Errorf("amneziawg: %w", err))
	}
	if err := runner.Run("ip", "link", "set", "dev", name, "up"); err != nil {
		return fail(fmt.Errorf("amneziawg: %w", err))
	}
	if cfg.Env.IPv6 {
		if err := runner.Run("ip", "-6", "addr", "add", protocols.AWGServerAddress6(), "dev", name); err != nil {
			return fail(fmt.Errorf("amneziawg: %w", err))
		}
	}
	return awgServer{dev: dev, r: runner, users: owners, ipv6: cfg.Env.IPv6}, nil
}
