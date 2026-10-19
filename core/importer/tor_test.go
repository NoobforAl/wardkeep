package importer

import (
	"reflect"
	"testing"
)

const testPrint = "0123456789ABCDEF0123456789ABCDEF01234567"

func TestTorLinkWithOwnBridges(t *testing.T) {
	obfs4 := "obfs4 192.0.2.5:443 " + testPrint + " cert=AbC+/x iat-mode=0"
	link := "tor://?bridge=obfs4+192.0.2.5%3A443+" + testPrint + "+cert%3DAbC%2B%2Fx+iat-mode%3D0&bridge=Bridge+snowflake+192.0.2.3%3A1+" + testPrint + "#Friends%20%26%20family"
	p, err := ParseLink(link)
	if err != nil {
		t.Fatal(err)
	}
	if p.Name != "Friends & family" {
		t.Errorf("name = %q", p.Name)
	}
	want := []string{obfs4, "snowflake 192.0.2.3:1 " + testPrint}
	if !reflect.DeepEqual(p.Tor.Bridges, want) {
		t.Errorf("bridges = %q, want %q", p.Tor.Bridges, want)
	}
	if p.Tor.Builtin != "" {
		t.Errorf("builtin = %q", p.Tor.Builtin)
	}

	// Without a name it is called what a pasted list of bridges is called.
	p, err = ParseLink("tor://?bridge=obfs4+192.0.2.5%3A443+" + testPrint)
	if err != nil || p.Name != "Tor (custom bridges)" {
		t.Errorf("name = %q, err = %v", p.Name, err)
	}

	// A list of links holds one with bridges next to the others, and a comment line is skipped.
	res, err := Import("# Wardkeep group: Mine\ntor://snowflake\n" + link + "\ntor://meek#Meek%20bridge")
	if err != nil || len(res.Profiles) != 3 {
		t.Fatalf("res = %+v, err = %v", res, err)
	}
	if res.Profiles[2].Name != "Meek bridge" || res.Profiles[2].Tor.Builtin != "meek" {
		t.Errorf("third = %+v", res.Profiles[2])
	}

	for _, bad := range []string{"tor://?bridge=hello", "tor://?bridge=", "tor://conjure"} {
		if p, err := ParseLink(bad); err == nil && bad != "tor://?bridge=" {
			t.Errorf("%s parsed: %+v", bad, p)
		}
	}
}
