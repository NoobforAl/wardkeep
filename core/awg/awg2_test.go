package awg

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/amnezia-vpn/amneziawg-go/conn"
	"github.com/amnezia-vpn/amneziawg-go/device"
	"github.com/amnezia-vpn/amneziawg-go/tun"
	"golang.org/x/crypto/curve25519"

	"github.com/NoobforAl/omnitun/core/importer"
)

func ep() netip.AddrPort { return netip.MustParseAddrPort("203.0.113.5:51820") }

// AmneziaWG 2.0: S3 and S4 and header ranges reach the device configuration, and amneziawg-go accepts it.
func TestUAPICarriesAWG2(t *testing.T) {
	text := strings.NewReplacer("H1 = 1", "H1 = 100-200", "H2 = 2", "H2 = 300-400", "H3 = 3", "H3 = 500-600", "H4 = 4", "H4 = 700-800\nS3 = 20\nS4 = 10\nI1 = <b 0xc0ff00><r 16>").Replace(conf)
	res, err := importer.Import(text)
	if err != nil {
		t.Fatal(err)
	}
	if got := Generation(res.Profiles[0].WireGuard.Amnezia); got != "2.0" {
		t.Errorf("generation = %q, want 2.0", got)
	}
	uapi, err := UAPI(res.Profiles[0], ep())
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"s3=20\n", "s4=10\n", "h1=100-200\n", "h2=300-400\n", "h3=500-600\n", "h4=700-800\n", "i1=<b 0xc0ff00><r 16>\n"} {
		if !strings.Contains(uapi, want) {
			t.Errorf("UAPI missing %q:\n%s", want, uapi)
		}
	}
	if strings.Index(uapi, "s4=") > strings.Index(uapi, "public_key=") {
		t.Error("device parameters after the peer section")
	}
	dev := device.NewDevice(newNopTun(), conn.NewDefaultBind(), &device.Logger{Verbosef: func(string, ...any) {}, Errorf: func(string, ...any) {}})
	defer dev.Close()
	if err := dev.IpcSet(uapi); err != nil {
		t.Fatalf("amneziawg-go rejected the configuration: %v", err)
	}
}

// The names AmneziaWG 1.5 had and 2.0 dropped (itime, j1-j3) do not make a connection fail: they are left out.
func TestUAPILeavesOutWhatTwoPointZeroDropped(t *testing.T) {
	res, err := importer.Import(strings.Replace(conf, "H4 = 4", "H4 = 4\nItime = 5\nJ1 = <b 0x01><r 8>\nJ2 = <r 4>\nI1 = <b 0xc0ff00>", 1))
	if err != nil {
		t.Fatal(err)
	}
	uapi, err := UAPI(res.Profiles[0], ep())
	if err != nil {
		t.Fatal(err)
	}
	for _, gone := range []string{"itime", "j1=", "j2="} {
		if strings.Contains(uapi, gone) {
			t.Errorf("UAPI still has %q:\n%s", gone, uapi)
		}
	}
	if !strings.Contains(uapi, "i1=<b 0xc0ff00>\n") {
		t.Errorf("the signature packet was lost:\n%s", uapi)
	}
	dev := device.NewDevice(newNopTun(), conn.NewDefaultBind(), &device.Logger{Verbosef: func(string, ...any) {}, Errorf: func(string, ...any) {}})
	defer dev.Close()
	if err := dev.IpcSet(uapi); err != nil {
		t.Fatalf("amneziawg-go rejected the configuration: %v", err)
	}
}

func TestParamsAreCheckedInWords(t *testing.T) {
	good := map[string]string{"jc": "4", "jmin": "40", "jmax": "70", "s1": "15", "s2": "20", "h1": "1", "h2": "2", "h3": "3", "h4": "4"}
	if err := CheckParams(good); err != nil {
		t.Fatalf("good parameters: %v", err)
	}
	with := func(k, v string) map[string]string {
		m := map[string]string{}
		for a, b := range good {
			m[a] = b
		}
		m[k] = v
		return m
	}
	for name, tc := range map[string]struct {
		params map[string]string
		want   string
	}{
		"a letter in a number":          {with("jc", "x"), "jc"},
		"a number that is too big":      {with("s3", "70000"), "s3"},
		"a range backwards":             {with("h1", "200-100"), "h1"},
		"a half range":                  {with("h1", "100-"), "h1"},
		"overlapping headers":           {with("h2", "1-5"), "overlap"},
		"the same header twice":         {with("h3", "2"), "overlap"},
		"s1 + 56 = s2":                  {with("s2", "71"), "s1 + 56"},
		"jmin above jmax":               {with("jmin", "90"), "jmin"},
		"a line break in a chain":       {with("i1", "<b 0x01>\nprivate_key=00"), "line break"},
		"a key nobody knows":            {with("zz", "1"), "zz"},
		"a range for a plain number":    {with("jc", "1-2"), "jc"},
		"an empty header":               {with("h4", ""), "h4"},
		"a negative number":             {with("s2", "-5"), "s2"},
		"a header range past 32 bits":   {with("h4", "1-99999999999"), "h4"},
		"a 2.0 range overlapping a 1.x": {with("h1", "0-10"), "overlap"},
	} {
		err := CheckParams(tc.params)
		if err == nil || !strings.Contains(err.Error(), tc.want) {
			t.Errorf("%s: err = %v, want it to mention %q", name, err, tc.want)
		}
	}
	if err := CheckParams(with("zz", "1")); !errors.Is(err, ErrUnsupported) {
		t.Errorf("an unknown key is %v, want ErrUnsupported", err)
	}
	if got := Generation(good); got != "1.x" {
		t.Errorf("generation of plain parameters = %q", got)
	}
	if got := Generation(with("i1", "<b 0x01>")); got != "1.5" {
		t.Errorf("generation with a signature packet = %q", got)
	}
}

// pairTun is a TUN device the test writes packets into and reads packets out of.
type pairTun struct {
	in     chan []byte
	events chan tun.Event
	closed chan struct{}
	once   sync.Once
}

func newPairTun() *pairTun {
	t := &pairTun{in: make(chan []byte, 8), events: make(chan tun.Event, 1), closed: make(chan struct{})}
	t.events <- tun.EventUp
	return t
}

func (t *pairTun) File() *os.File           { return nil }
func (t *pairTun) MTU() (int, error)        { return 1280, nil }
func (t *pairTun) Name() (string, error)    { return "pair", nil }
func (t *pairTun) Events() <-chan tun.Event { return t.events }
func (t *pairTun) BatchSize() int           { return 1 }
func (t *pairTun) Read(bufs [][]byte, sizes []int, offset int) (int, error) {
	select {
	case p := <-t.in:
		sizes[0] = copy(bufs[0][offset:], p)
		return 1, nil
	case <-t.closed:
		return 0, os.ErrClosed
	}
}
func (t *pairTun) Write(bufs [][]byte, _ int) (int, error) { return len(bufs), nil }
func (t *pairTun) Close() error {
	t.once.Do(func() { close(t.closed) })
	return nil
}

// ipv4Packet is a minimal UDP-over-IPv4 packet from src to dst.
func ipv4Packet(src, dst string) []byte {
	p := make([]byte, 28)
	p[0], p[3], p[8], p[9] = 0x45, 28, 64, 17
	copy(p[12:16], net.ParseIP(src).To4())
	copy(p[16:20], net.ParseIP(dst).To4())
	p[25] = 8
	return p
}

func udpPort(t *testing.T) int {
	t.Helper()
	c, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	return c.LocalAddr().(*net.UDPAddr).Port
}

// handshakes starts a server and a client device with the given obfuscation lines and reports whether
// the client's first packet makes them shake hands within the wait.
func handshakes(t *testing.T, serverLines, clientLines string, wait time.Duration) bool {
	t.Helper()
	const clientPriv = "c809f3e531de50bc2a4e0f2ae5ac1f33d95b9d0b6fb6c0a46c8a0f8fd3eb4a3b"
	const serverPriv = "d0b0b4e2c1f7e1e0e1d1c1b1a191817161514131211101f0e0d0c0b0a0908070"
	logger := &device.Logger{Verbosef: func(string, ...any) {}, Errorf: func(string, ...any) {}}

	srvTun, cliTun := newPairTun(), newPairTun()
	srv := device.NewDevice(srvTun, conn.NewDefaultBind(), logger)
	cli := device.NewDevice(cliTun, conn.NewDefaultBind(), logger)
	defer srv.Close()
	defer cli.Close()

	port := udpPort(t)
	pubOf := func(priv string) string {
		raw, err := hex.DecodeString(priv)
		if err != nil || len(raw) != 32 {
			t.Fatal("bad test key")
		}
		pub, err := curve25519.X25519(raw, curve25519.Basepoint)
		if err != nil {
			t.Fatal(err)
		}
		return hex.EncodeToString(pub)
	}
	srvPub, cliPub := pubOf(serverPriv), pubOf(clientPriv)

	if err := srv.IpcSet(fmt.Sprintf("private_key=%s\nlisten_port=%d\n%sreplace_peers=true\npublic_key=%s\nallowed_ip=10.9.0.2/32\n", serverPriv, port, serverLines, cliPub)); err != nil {
		t.Fatal(err)
	}
	if err := cli.IpcSet(fmt.Sprintf("private_key=%s\n%sreplace_peers=true\npublic_key=%s\nendpoint=127.0.0.1:%d\nallowed_ip=10.9.0.0/24\npersistent_keepalive_interval=1\n", clientPriv, clientLines, srvPub, port)); err != nil {
		t.Fatal(err)
	}
	if err := srv.Up(); err != nil {
		t.Fatal(err)
	}
	if err := cli.Up(); err != nil {
		t.Fatal(err)
	}
	cliTun.in <- ipv4Packet("10.9.0.2", "10.9.0.1")

	deadline := time.Now().Add(wait)
	for time.Now().Before(deadline) {
		if shook(srv) && shook(cli) {
			return true
		}
		time.Sleep(100 * time.Millisecond)
	}
	return false
}

func shook(d *device.Device) bool {
	raw, err := d.IpcGet()
	if err != nil {
		return false
	}
	for l := range strings.SplitSeq(raw, "\n") {
		if k, v, ok := strings.Cut(l, "="); ok && k == "last_handshake_time_sec" && v != "0" {
			return true
		}
	}
	return false
}

// The obfuscation is real: both ends must agree. A client and a server with the same AmneziaWG 1.x,
// 1.5 or 2.0 parameters shake hands; with different parameters the packets are not recognised.
func TestHandshakeNeedsTheSameParameters(t *testing.T) {
	v1 := "jc=3\njmin=40\njmax=70\ns1=15\ns2=20\nh1=11\nh2=22\nh3=33\nh4=44\n"
	v2 := "jc=3\njmin=40\njmax=70\ns1=15\ns2=20\ns3=18\ns4=9\nh1=100-200\nh2=300-400\nh3=500-600\nh4=700-800\n"
	v2other := "jc=3\njmin=40\njmax=70\ns1=15\ns2=20\ns3=18\ns4=9\nh1=1000-2000\nh2=3000-4000\nh3=5000-6000\nh4=7000-8000\n"
	v2withI := v2 + "i1=<b 0xc0ff00><r 16>\n"
	for name, tc := range map[string]struct {
		server, client string
		want           bool
	}{
		"1.x on both sides":                             {v1, v1, true},
		"2.0 on both sides (s3, s4, header ranges)":     {v2, v2, true},
		"2.0 with a signature packet from the client":   {v2, v2withI, true},
		"2.0 against 1.x":                               {v1, v2, false},
		"2.0 with different header ranges":              {v2, v2other, false},
		"2.0 against a server with different s3 and s4": {strings.Replace(v2, "s3=18\ns4=9", "s3=30\ns4=3", 1), v2, false},
	} {
		wait := 8 * time.Second
		if !tc.want {
			wait = 3 * time.Second
		}
		if got := handshakes(t, tc.server, tc.client, wait); got != tc.want {
			t.Errorf("%s: shook hands = %v, want %v", name, got, tc.want)
		}
	}
}
