package links

import (
	"testing"

	"github.com/NoobforAl/wardkeep/core/importer"
)

// The worked example of HOW-TO-CONNECT.md comes back out byte for byte.
const rvpnDocLink = "rvpn://k3j9q2xw7a.example.org:443/api/v1/q7w2e9r4t1y6u3i8?v=1" +
	"&ik=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE" +
	"&ixk=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI" +
	"&ixs=AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw" +
	"&spk=BAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ" +
	"&pks=BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQ" +
	"&ikv=1&alt=m8d2p0zr4c.example.net#rVPN"

func TestRVPNExportDocExample(t *testing.T) {
	p, err := importer.ParseLink(rvpnDocLink)
	if err != nil {
		t.Fatal(err)
	}
	got, err := Export(p)
	if err != nil {
		t.Fatal(err)
	}
	if got != rvpnDocLink {
		t.Fatalf("export =\n%s\nwant\n%s", got, rvpnDocLink)
	}
}
