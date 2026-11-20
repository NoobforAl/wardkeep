package importer

import (
	"encoding/base64"
	"errors"
	"strings"
	"testing"

	"github.com/NoobforAl/wardkeep/core/profile"
)

// rvpnDocLink is the worked example of HOW-TO-CONNECT.md: every key is one byte repeated.
const rvpnDocLink = "rvpn://k3j9q2xw7a.example.org:443/api/v1/q7w2e9r4t1y6u3i8?v=1" +
	"&ik=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE" +
	"&ixk=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI" +
	"&ixs=AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw" +
	"&spk=BAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ" +
	"&pks=BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQ" +
	"&ikv=1&alt=m8d2p0zr4c.example.net#rVPN"

func repeated(b byte, n int) string {
	return base64.StdEncoding.EncodeToString([]byte(strings.Repeat(string(rune(b)), n)))
}

func TestRVPNDocExample(t *testing.T) {
	p, err := ParseLink(rvpnDocLink)
	if err != nil {
		t.Fatal(err)
	}
	if p.Protocol != profile.RVPN || p.Server != "k3j9q2xw7a.example.org" || p.Port != 443 || p.Name != "rVPN" {
		t.Fatalf("profile = %+v", p)
	}
	o := p.RVPN
	if o.Path != "/api/v1/q7w2e9r4t1y6u3i8" || len(o.Alt) != 1 || o.Alt[0] != "m8d2p0zr4c.example.net" {
		t.Fatalf("opts = %+v", o)
	}
	want := profile.RVPNBundle{
		IdentityKey: repeated(1, 32), IdentityX25519Key: repeated(2, 32), IdentityX25519Signature: repeated(3, 64),
		SignedPrekey: repeated(4, 32), PrekeySignature: repeated(5, 64), IdentityKeyVersion: 1,
	}
	if o.Bundle != want {
		t.Fatalf("bundle = %+v\nwant     %+v", o.Bundle, want)
	}
	// The bundle file the helper reads is the document's JSON: absent keys are null.
	js, err := o.Bundle.FileJSON()
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range []string{`"one_time_prekey": null`, `"rotation_signature": null`, `"identity_key_version": 1`,
		`"identity_key": "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE="`} {
		if !strings.Contains(string(js), s) {
			t.Errorf("bundle JSON lacks %s:\n%s", s, js)
		}
	}
}

func TestRVPNLinkRejects(t *testing.T) {
	cases := map[string]string{
		"no version":      strings.Replace(rvpnDocLink, "?v=1", "?x=1", 1),
		"newer version":   strings.Replace(rvpnDocLink, "?v=1", "?v=2", 1),
		"no path":         strings.Replace(rvpnDocLink, "/api/v1/q7w2e9r4t1y6u3i8", "", 1),
		"short key":       strings.Replace(rvpnDocLink, "ik=AQEBAQEB", "ik=AQEB", 1),
		"no x25519 sig":   strings.Replace(rvpnDocLink, "&ixs=", "&zzz=", 1),
		"not base64":      strings.Replace(rvpnDocLink, "spk=BAQE", "spk=!!!!", 1),
		"user info":       strings.Replace(rvpnDocLink, "rvpn://", "rvpn://user:pw@", 1),
		"ip server":       strings.Replace(rvpnDocLink, "k3j9q2xw7a.example.org", "203.0.113.5", 1),
		"bad port":        strings.Replace(rvpnDocLink, ":443/", ":99999/", 1),
		"bad alt":         strings.Replace(rvpnDocLink, "alt=m8d2p0zr4c.example.net", "alt=bad_host!", 1),
		"bad key version": strings.Replace(rvpnDocLink, "ikv=1", "ikv=0", 1),
	}
	for name, link := range cases {
		if p, err := ParseLink(link); err == nil {
			t.Errorf("%s: accepted %+v", name, p)
		}
	}
}

func TestRVPNLinkLenient(t *testing.T) {
	// Padded keys, an unknown parameter, no port and no name are all fine.
	link := strings.Replace(rvpnDocLink, "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE", "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=", 1)
	link = strings.Replace(link, ":443/", "/", 1)
	link = strings.Replace(link, "&ikv=1", "&ikv=1&future=yes", 1)
	link = strings.TrimSuffix(link, "#rVPN")
	p, err := ParseLink(link)
	if err != nil {
		t.Fatal(err)
	}
	if p.Port != 443 || p.Name != "rVPN" {
		t.Fatalf("profile = %+v", p)
	}
}

const rvpnBundleJSON = `{
  "identity_key": "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=",
  "identity_x25519_key": "AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=",
  "identity_x25519_signature": "AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw==",
  "signed_prekey": "BAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ=",
  "prekey_signature": "BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQ==",
  "one_time_prekey": null,
  "identity_key_version": 1,
  "rotation_signature": null
}`

func TestRVPNBundleAlone(t *testing.T) {
	_, err := Import(rvpnBundleJSON)
	if !errors.Is(err, ErrRVPNNeedsServer) {
		t.Fatalf("err = %v, want ErrRVPNNeedsServer", err)
	}
}

func TestRVPNBundleWithServer(t *testing.T) {
	for _, text := range []string{
		"wss://vpn.example.org/api/v1/ws\n" + rvpnBundleJSON,
		rvpnBundleJSON + "\nserver_address = \"wss://vpn.example.org:443/api/v1/ws\"\n",
	} {
		res, err := Import(text)
		if err != nil {
			t.Fatal(err)
		}
		p := res.Profiles[0]
		if p.Protocol != profile.RVPN || p.Server != "vpn.example.org" || p.Port != 443 || p.RVPN.Path != "/api/v1/ws" {
			t.Fatalf("profile = %+v %+v", p, p.RVPN)
		}
	}
}

func TestRVPNBundleBadKey(t *testing.T) {
	bad := strings.Replace(rvpnBundleJSON, `"signed_prekey": "BAQE`, `"signed_prekey": "BA`, 1)
	if _, err := Import("wss://vpn.example.org/p\n" + bad); err == nil || errors.Is(err, ErrRVPNNeedsServer) {
		t.Fatalf("err = %v, want a key error", err)
	}
}
