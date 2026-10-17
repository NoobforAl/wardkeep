package hostproto

import (
	"maps"
	"net"
	"net/netip"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/amnezia-vpn/amneziawg-go/conn"
	"github.com/amnezia-vpn/amneziawg-go/device"
	"github.com/amnezia-vpn/amneziawg-go/tun"

	"github.com/NoobforAl/omnitun/core/awg"
	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/links"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/protocols"
	"github.com/NoobforAl/omnitun/server/store"
)

// fakeTun is a tun.Device the test feeds and reads. With respond set it plays
// the host side of the tunnel and answers ICMP echo requests.
type fakeTun struct {
	in      chan []byte // packets the device reads from the "interface"
	out     chan []byte // packets the device wrote to it
	events  chan tun.Event
	closed  chan struct{}
	respond bool
}

func newFakeTun(respond bool) *fakeTun {
	t := &fakeTun{in: make(chan []byte, 16), out: make(chan []byte, 16), events: make(chan tun.Event, 1), closed: make(chan struct{}), respond: respond}
	t.events <- tun.EventUp
	return t
}

func (t *fakeTun) File() *os.File           { return nil }
func (t *fakeTun) MTU() (int, error)        { return awgMTU, nil }
func (t *fakeTun) Name() (string, error)    { return awgInterface, nil }
func (t *fakeTun) Events() <-chan tun.Event { return t.events }
func (t *fakeTun) BatchSize() int           { return 1 }

func (t *fakeTun) Read(bufs [][]byte, sizes []int, offset int) (int, error) {
	select {
	case p := <-t.in:
		sizes[0] = copy(bufs[0][offset:], p)
		return 1, nil
	case <-t.closed:
		return 0, os.ErrClosed
	}
}

func (t *fakeTun) Write(bufs [][]byte, offset int) (int, error) {
	for _, b := range bufs {
		p := append([]byte(nil), b[offset:]...)
		if t.respond {
			if r := echoReply(p); r != nil {
				select {
				case t.in <- r:
				default:
				}
			}
			continue
		}
		select {
		case t.out <- p:
		default:
		}
	}
	return len(bufs), nil
}

func (t *fakeTun) Close() error {
	select {
	case <-t.closed:
	default:
		close(t.closed)
		close(t.events)
	}
	return nil
}

func freeUDP(t *testing.T) int {
	t.Helper()
	c, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	return c.LocalAddr().(*net.UDPAddr).Port
}

// fakeTunOpener makes the server use a fake TUN device for the test.
func fakeTunOpener(t *testing.T) {
	t.Helper()
	real := openTUN
	openTUN = func(string, int) (tun.Device, error) { return newFakeTun(true), nil }
	t.Cleanup(func() { openTUN = real })
}

// awgFixture is a started AmneziaWG server and the pieces to build clients.
type awgFixture struct {
	srv  Server
	port int
	env  protocols.Env
	user protocols.Account
	run  *fakeRunner
}

func awgEnv(t *testing.T) (protocols.Env, protocols.Account) {
	t.Helper()
	return awgEnvVersion(t, store.AWG2)
}

// awgEnvVersion is awgEnv with AmneziaWG 2.0 or classic 1.x parameters.
func awgEnvVersion(t *testing.T, version string) (protocols.Env, protocols.Account) {
	t.Helper()
	a, err := store.NewAmneziaWGVersion(version)
	if err != nil {
		t.Fatal(err)
	}
	priv, pub, err := store.NewWireGuardKeys()
	if err != nil {
		t.Fatal(err)
	}
	e := env()
	e.AWG = protocols.AmneziaWG{PrivateKey: a.PrivateKey, PublicKey: a.PublicKey, Params: a.Params}
	return e, protocols.Account{Name: "alice", Password: "pw", WGPrivateKey: priv, WGPublicKey: pub, WGAddress: "10.30.0.2/32"}
}

func startAWGServer(t *testing.T) *awgFixture {
	t.Helper()
	return startAWGServerVersion(t, store.AWG2)
}

func startAWGServerVersion(t *testing.T, version string) *awgFixture {
	t.Helper()
	fakeTunOpener(t)
	e, user := awgEnvVersion(t, version)
	run := &fakeRunner{}
	port := freeUDP(t)
	srv, err := Start("amneziawg", Config{Env: e, Port: port, Users: []protocols.Account{user}, Runner: run})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { srv.Close() })
	return &awgFixture{srv: srv, port: port, env: e, user: user, run: run}
}

// pingAWG connects a client built from the registry's profile (with tweak
// applied) and reports whether an echo to the server's tunnel address is
// answered within wait.
func (f *awgFixture) pingAWG(t *testing.T, wait time.Duration, tweak func(*protocols.Account, *protocols.Env)) bool {
	t.Helper()
	user, e := f.user, f.env
	if tweak != nil {
		tweak(&user, &e)
	}
	proto, _ := protocols.Get("amneziawg")
	p, err := proto.Profile(e, f.port, user)
	if err != nil {
		t.Fatal(err)
	}
	return f.pingProfile(t, p, wait)
}

// pingProfile connects a client device configured from p, the way the
// engines do, and reports whether the server answers an echo request.
func (f *awgFixture) pingProfile(t *testing.T, p *profile.Profile, wait time.Duration) bool {
	t.Helper()
	// The same device configuration the Android engine applies.
	uapi, err := awg.UAPI(p, netip.MustParseAddrPort("127.0.0.1:"+strconv.Itoa(f.port)))
	if err != nil {
		t.Fatal(err)
	}
	tn := newFakeTun(false)
	dev := device.NewDevice(tn, conn.NewDefaultBind(), &device.Logger{Verbosef: func(string, ...any) {}, Errorf: func(string, ...any) {}})
	defer dev.Close()
	if err := dev.IpcSet(uapi); err != nil {
		t.Fatal(err)
	}
	if err := dev.Up(); err != nil {
		t.Fatal(err)
	}
	src := net.ParseIP(strings.TrimSuffix(p.WireGuard.Address[0], "/32"))
	gateway := net.ParseIP("10.31.0.1")
	deadline := time.Now().Add(wait)
	for time.Now().Before(deadline) {
		select {
		case tn.in <- echoRequest(src, gateway, 9):
		default:
		}
		select {
		case r := <-tn.out:
			return len(r) >= 28 && r[20] == 0 && net.IP(r[12:16]).Equal(gateway)
		case <-time.After(300 * time.Millisecond):
		}
	}
	return false
}

func TestAmneziaWGServerAndGeneratedProfile(t *testing.T) {
	f := startAWGServer(t)
	if f.srv.Pool() != protocols.AWGPool {
		t.Fatalf("pool = %s", f.srv.Pool())
	}
	cmds := strings.Join(f.run.ran, "\n")
	for _, want := range []string{"ip addr add 10.31.0.1/16 dev omnitun-awg", "ip link set dev omnitun-awg up"} {
		if !strings.Contains(cmds, want) {
			t.Errorf("the interface was not set up: missing %q in %q", want, cmds)
		}
	}
	if !f.pingAWG(t, 10*time.Second, nil) {
		t.Fatal("the generated AmneziaWG profile did not carry a ping")
	}
}

func TestAmneziaWGServerRefusesStrangers(t *testing.T) {
	f := startAWGServer(t)
	if f.pingAWG(t, 2*time.Second, func(u *protocols.Account, _ *protocols.Env) {
		priv, pub, _ := store.NewWireGuardKeys()
		u.WGPrivateKey, u.WGPublicKey = priv, pub
	}) {
		t.Error("a client with an unknown key was served")
	}
	// Mismatched obfuscation parameters are not tested here: amneziawg-go keeps the
	// header values in package-level variables, so a client and a server in one
	// process always share them (a real server process runs a single device).
}

func TestAmneziaWGServerRefusesBadSetup(t *testing.T) {
	fakeTunOpener(t)
	e, user := awgEnv(t)

	if _, err := Start("amneziawg", Config{Env: e, Port: freeUDP(t), Users: []protocols.Account{{Name: "nokey"}}, Runner: &fakeRunner{}}); err == nil {
		t.Error("started with no user having a WireGuard key")
	}
	e2 := e
	e2.AWG.Params = map[string]string{"jc": "4"}
	if _, err := Start("amneziawg", Config{Env: e2, Port: freeUDP(t), Users: []protocols.Account{user}, Runner: &fakeRunner{}}); err == nil {
		t.Error("started with missing obfuscation parameters")
	}
	// A failing `ip` leaves no half-started device.
	run := &fakeRunner{failing: map[string]bool{"ip link set dev omnitun-awg up": true}}
	if _, err := Start("amneziawg", Config{Env: e, Port: freeUDP(t), Users: []protocols.Account{user}, Runner: run}); err == nil {
		t.Error("started although the interface could not be brought up")
	}
}

// The device's peer counters become per-user usage.
func TestAmneziaWGCountsTrafficPerUser(t *testing.T) {
	f := startAWGServer(t)
	m, ok := f.srv.(Meter)
	if !ok {
		t.Fatalf("%T does not count traffic per user", f.srv)
	}
	usage := func() Usage {
		for _, u := range m.Usage() {
			if u.User == "alice" {
				return u
			}
		}
		return Usage{}
	}
	if u := usage(); u.Up != 0 || u.Down != 0 {
		t.Fatalf("traffic before anyone connected: %+v", u)
	}
	if !f.pingAWG(t, 10*time.Second, nil) {
		t.Fatal("no ping through the tunnel")
	}
	u := usage()
	if u.Up < 28 || u.Down < 28 {
		t.Fatalf("usage after a ping: %+v", u)
	}
	for _, other := range m.Usage() {
		if other.User == "" {
			t.Fatal("a peer without an owner was reported")
		}
	}
}

// importedProfiles are the client profiles a user's device gets from what the
// server hands out: the awg:// link and the .conf file, read by the importer
// of the app.
func importedProfiles(t *testing.T, f *awgFixture) map[string]*profile.Profile {
	t.Helper()
	proto, _ := protocols.Get("amneziawg")
	p, err := proto.Profile(f.env, f.port, f.user)
	if err != nil {
		t.Fatal(err)
	}
	link, err := links.Export(p)
	if err != nil {
		t.Fatal(err)
	}
	_, conf, err := proto.(protocols.FileProtocol).File(f.env, f.port, f.user)
	if err != nil {
		t.Fatal(err)
	}
	out := map[string]*profile.Profile{}
	for what, text := range map[string]string{"link": link, "conf": conf} {
		res, err := importer.Import(text)
		if err != nil || len(res.Profiles) != 1 || res.Profiles[0].Protocol != profile.AmneziaWG {
			t.Fatalf("importing the %s: %v %+v\n%s", what, err, res, text)
		}
		out[what] = res.Profiles[0]
	}
	return out
}

// A device built from the link or the .conf the server hands out shakes hands
// with the server's own device and carries a ping, for AmneziaWG 2.0 (header
// ranges, s3, s4) and for a classic 1.x interface alike.
func TestAmneziaWGHandshakeFromTheHandedOutLinkAndConf(t *testing.T) {
	for _, version := range []string{store.AWG2, store.AWGClassic} {
		t.Run(version, func(t *testing.T) {
			f := startAWGServerVersion(t, version)
			wantGen := map[string]string{store.AWG2: "2.0", store.AWGClassic: "1.x"}[version]
			if got := awg.Generation(f.env.AWG.Params); got != wantGen {
				t.Fatalf("server parameters are generation %s, want %s", got, wantGen)
			}
			for what, p := range importedProfiles(t, f) {
				if !maps.Equal(p.WireGuard.Amnezia, f.env.AWG.Params) {
					t.Fatalf("the %s changed the parameters:\nserver %v\nclient %v", what, f.env.AWG.Params, p.WireGuard.Amnezia)
				}
				if err := awg.CheckParams(p.WireGuard.Amnezia); err != nil {
					t.Fatalf("the %s: %v", what, err)
				}
				if !f.pingProfile(t, p, 10*time.Second) {
					t.Fatalf("the device built from the %s did not carry a ping", what)
				}
			}
		})
	}
}

// Parameters that differ from the server's are not served: a 2.0 client does
// not get through to a 1.x server (the library hides the server, so the ping
// is never answered), which is what makes "same parameters" a real condition.
func TestAmneziaWGClientWithAnotherVersionIsNotAnswered(t *testing.T) {
	f := startAWGServerVersion(t, store.AWGClassic)
	other, err := store.NewAWGParams(store.AWG2)
	if err != nil {
		t.Fatal(err)
	}
	if f.pingAWG(t, 2*time.Second, func(_ *protocols.Account, e *protocols.Env) { e.AWG.Params = other }) {
		t.Fatal("a 2.0 client reached a 1.x server")
	}
}

// Many different 2.0 parameter sets are accepted by amneziawg-go itself, as
// the server's device configuration.
func TestAmneziaWGServerAcceptsEveryGeneratedParameterSet(t *testing.T) {
	for range 100 {
		e, user := awgEnvVersion(t, store.AWG2)
		uapi, _, err := awgUAPI(Config{Env: e, Port: 51821, Users: []protocols.Account{user}})
		if err != nil {
			t.Fatal(err)
		}
		dev := device.NewDevice(newFakeTun(false), conn.NewDefaultBind(), &device.Logger{Verbosef: func(string, ...any) {}, Errorf: func(string, ...any) {}})
		err = dev.IpcSet(strings.Replace(uapi, "listen_port=51821\n", "", 1))
		dev.Close()
		if err != nil {
			t.Fatalf("amneziawg-go rejected %v: %v", e.AWG.Params, err)
		}
	}
}
