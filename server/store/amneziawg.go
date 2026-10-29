package store

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/awg"
)

// AmneziaWGSubnet is the AmneziaWG tunnel network: the server takes .1 and a
// user's address is their WireGuard address moved into this network (10.30.a.b
// becomes 10.31.a.b), so the two servers can run together.
const AmneziaWGSubnet = "10.31.0.0/16"

// AmneziaWG is the server's AmneziaWG identity and obfuscation settings.
type AmneziaWG struct {
	PrivateKey string `json:"private_key"`
	PublicKey  string `json:"public_key"`
	// Params are the obfuscation parameters (jc, jmin, jmax, s1, s2, h1-h4, and
	// in AmneziaWG 2.0 s3, s4 with header ranges) clients must use too.
	Params map[string]string `json:"params"`
}

// The two kinds of AmneziaWG interface a server can have.
const (
	// AWGClassic is AmneziaWG 1.x: single-number headers h1-h4, paddings s1 and s2.
	AWGClassic = "1.x"
	// AWG2 is AmneziaWG 2.0: header ranges, paddings s3 and s4 as well.
	//
	// It is the default for a new interface. 1.x gives every packet of a kind
	// the same four header numbers and the same two padding sizes, which is what
	// the DPI systems that learned to spot AmneziaWG 1.x look for; 2.0 draws the
	// header from a range for every packet and also pads the cookie and the data
	// packets, so there is no fixed signature left. The clients that matter here
	// (Wardkeep and the AmneziaWG apps) read 2.0. 1.x stays for old third-party
	// clients that were never updated.
	AWG2 = "2.0"
)

// ParseAWGVersion reads a version typed by a person or sent to the API: "2.0"
// (also "2", "new", "default" and empty) or "1.x" (also "1", "1.0", "classic").
func ParseAWGVersion(text string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(text)) {
	case "", "2", "2.0", "new", "default":
		return AWG2, nil
	case "1", "1.x", "1.0", "classic":
		return AWGClassic, nil
	}
	return "", fmt.Errorf("unknown AmneziaWG version %q (use 2.0 or 1.x)", text)
}

// Version tells which AmneziaWG generation the stored parameters are.
func (a AmneziaWG) Version() string {
	if awg.Generation(a.Params) == "2.0" {
		return AWG2
	}
	return AWGClassic
}

// randUint returns a random integer in [lo, hi].
func randUint(lo, hi uint32) uint32 {
	var b [4]byte
	rand.Read(b[:])
	return lo + binary.BigEndian.Uint32(b[:])%(hi-lo+1)
}

// NewAmneziaWG makes a key pair and obfuscation parameters of the default
// kind, AmneziaWG 2.0.
func NewAmneziaWG() (AmneziaWG, error) { return NewAmneziaWGVersion(AWG2) }

// NewAmneziaWGVersion makes a key pair and random obfuscation parameters of
// the given version (AWGClassic or AWG2).
func NewAmneziaWGVersion(version string) (AmneziaWG, error) {
	priv, pub, err := NewWireGuardKeys()
	if err != nil {
		return AmneziaWG{}, err
	}
	params, err := NewAWGParams(version)
	if err != nil {
		return AmneziaWG{}, err
	}
	return AmneziaWG{PrivateKey: priv, PublicKey: pub, Params: params}, nil
}

// NewAWGParams makes random obfuscation parameters of the given version that
// pass awg.CheckParams and that amneziawg-go accepts.
func NewAWGParams(version string) (map[string]string, error) {
	v, err := ParseAWGVersion(version)
	if err != nil {
		return nil, err
	}
	if v == AWGClassic {
		return classicAWGParams(), nil
	}
	return awg2Params(), nil
}

func u32(v uint32) string { return strconv.FormatUint(uint64(v), 10) }

// paddingsS1S2 draws the paddings of the handshake's first two packets: the
// init packet is 148 bytes and the response 92, so s1 + 56 == s2 would make
// them the same length and the two could be told apart no more.
func paddingsS1S2(lo, hi uint32) (s1, s2 uint32) {
	s1 = randUint(lo, hi)
	s2 = randUint(lo, hi)
	for s2 == s1+56 {
		s2 = randUint(lo, hi)
	}
	return s1, s2
}

// classicAWGParams are AmneziaWG 1.x parameters: jmin < jmax <= 1280, s1 and s2
// as above, and four distinct single-number headers that are not WireGuard's
// own 1-4.
func classicAWGParams() map[string]string {
	jmin := randUint(40, 80)
	s1, s2 := paddingsS1S2(15, 120)
	hs := map[uint32]bool{}
	var hdr [4]uint32
	for i := range hdr {
		for {
			v := randUint(5, 0x7fffffff)
			if !hs[v] {
				hs[v], hdr[i] = true, v
				break
			}
		}
	}
	return map[string]string{
		"jc": u32(randUint(4, 10)), "jmin": u32(jmin), "jmax": u32(jmin + randUint(30, 120)),
		"s1": u32(s1), "s2": u32(s2), "h1": u32(hdr[0]), "h2": u32(hdr[1]), "h3": u32(hdr[2]), "h4": u32(hdr[3]),
	}
}

// awg2Params are AmneziaWG 2.0 parameters.
//
//   - jc 4-12, jmin 20-60, jmax 30-150 above jmin (at most 1280): the junk
//     packets before a handshake, in the range the AmneziaWG project suggests.
//   - s1, s2 15-150 apart from s1 + 56 == s2, s3 16-64 and s4 8-32. The packets
//     they pad are 148, 92, 64 and 32+ bytes, and a WireGuard UDP packet must
//     stay under the path's MTU (1280 for the tunnel): s1 <= 1132, s2 <= 1188,
//     s3 <= 1216; these ranges stay far inside that, and small paddings leave
//     room for the data packets, which are padded by s4 on top of the payload.
//   - h1-h4: four ranges that do not touch each other and start above 4 (1-4
//     are plain WireGuard's message types, which any filter knows). The space
//     5..2^31-1 is cut into four slots, one range sits inside each, and which
//     header gets which slot is shuffled, so the order tells nothing either.
func awg2Params() map[string]string {
	jmin := randUint(20, 60)
	s1, s2 := paddingsS1S2(15, 150)

	const top = 0x7fffffff
	slot := uint32((top - 5) / 4)
	order := [4]int{0, 1, 2, 3}
	for i := len(order) - 1; i > 0; i-- {
		j := int(randUint(0, uint32(i)))
		order[i], order[j] = order[j], order[i]
	}
	params := map[string]string{
		"jc": u32(randUint(4, 12)), "jmin": u32(jmin), "jmax": u32(jmin + randUint(30, 150)),
		"s1": u32(s1), "s2": u32(s2), "s3": u32(randUint(16, 64)), "s4": u32(randUint(8, 32)),
	}
	for i, key := range []string{"h1", "h2", "h3", "h4"} {
		base := 5 + uint32(order[i])*slot //nolint:gosec // G115: order is a permutation of 0..3
		// A width from 64Ki to 16Mi values, put at a random place with a gap to the slot's ends.
		width := randUint(1<<16, 1<<24)
		lo := base + randUint(1, slot-width-1)
		params[key] = u32(lo) + "-" + u32(lo+width)
	}
	return params
}
