package hostproto

import (
	"encoding/binary"
	"net"
	"os"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/core/protocols"
)

func checksum(b []byte) uint16 {
	var sum uint32
	for i := 0; i+1 < len(b); i += 2 {
		sum += uint32(binary.BigEndian.Uint16(b[i:]))
	}
	if len(b)%2 == 1 {
		sum += uint32(b[len(b)-1]) << 8
	}
	for sum>>16 != 0 {
		sum = sum&0xffff + sum>>16
	}
	return ^uint16(sum)
}

func echoRequest(src, dst net.IP, id uint16) []byte {
	p := make([]byte, 36)
	p[0], p[8], p[9] = 0x45, 64, 1
	binary.BigEndian.PutUint16(p[2:], uint16(len(p)))
	copy(p[12:16], src.To4())
	copy(p[16:20], dst.To4())
	binary.BigEndian.PutUint16(p[10:], checksum(p[:20]))
	p[20] = 8
	binary.BigEndian.PutUint16(p[24:], id)
	copy(p[28:], "omnitun!")
	binary.BigEndian.PutUint16(p[22:], checksum(p[20:]))
	return p
}

func echoReply(p []byte) []byte {
	if len(p) < 28 || p[0]>>4 != 4 || p[9] != 1 || p[20] != 8 {
		return nil
	}
	r := append([]byte(nil), p...)
	copy(r[12:16], p[16:20])
	copy(r[16:20], p[12:16])
	r[10], r[11] = 0, 0
	binary.BigEndian.PutUint16(r[10:], checksum(r[:20]))
	r[20], r[22], r[23] = 0, 0, 0
	binary.BigEndian.PutUint16(r[22:], checksum(r[20:]))
	return r
}

func tempDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "omnitun-host-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		for i := 0; i < 40 && os.RemoveAll(dir) != nil; i++ {
			time.Sleep(50 * time.Millisecond)
		}
	})
	return dir
}

func env() protocols.Env {
	return protocols.Env{Name: "Lab", Host: "127.0.0.1"}
}

func TestStartRefusesWhatItCannotServe(t *testing.T) {
	if _, err := Start("amneziawg", Config{Env: env(), Port: 1}); err == nil {
		t.Error("started without users")
	}
	alice := protocols.Account{Name: "alice", Password: "alice-password"}
	for _, key := range []string{"trojan", "sstp", "ikev2"} {
		if _, err := Start(key, Config{Env: env(), Users: []protocols.Account{alice}}); err == nil {
			t.Errorf("started %s, which is not a host-level protocol", key)
		}
	}
}
