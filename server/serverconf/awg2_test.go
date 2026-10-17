package serverconf

import (
	"maps"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/awg"
	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/server/store"
)

// What a new server hands out for AmneziaWG (the share link, the .conf file and
// the profile of the subscription) carries every 2.0 key, and the importer of
// the app reads each of them back to the server's own parameters.
func TestAmneziaWG2LinkAndFileRoundTrip(t *testing.T) {
	for _, version := range []string{store.AWG2, store.AWGClassic} {
		s := store.Open(t.TempDir())
		st, err := store.Init(s, store.InitOptions{PublicHost: "203.0.113.7", AmneziaWGVersion: version, Enabled: []string{"amneziawg"}})
		if err != nil {
			t.Fatal(err)
		}
		u, err := store.AddUser(st, "alice")
		if err != nil {
			t.Fatal(err)
		}
		want := st.Server.AmneziaWG.Params

		var link string
		for _, l := range Links(st, s, u) {
			if l.Protocol == "amneziawg" {
				link = l.URL
			}
		}
		_, conf, err := File(st, u, "amneziawg")
		if err != nil || link == "" {
			t.Fatalf("%s: link %q, file error %v", version, link, err)
		}
		profiles, err := Profiles(st, s, u)
		if err != nil || len(profiles) != 1 {
			t.Fatalf("%s: profiles %v %v", version, profiles, err)
		}
		got := map[string]map[string]string{"profile": profiles[0].WireGuard.Amnezia}
		for what, text := range map[string]string{"link": link, "conf": conf} {
			res, err := importer.Import(text)
			if err != nil || len(res.Profiles) != 1 {
				t.Fatalf("%s %s: %v\n%s", version, what, err, text)
			}
			got[what] = res.Profiles[0].WireGuard.Amnezia
		}
		for what, params := range got {
			if !maps.Equal(params, want) {
				t.Errorf("%s %s: parameters changed\nserver %v\nclient %v", version, what, want, params)
			}
			if err := awg.CheckParams(params); err != nil {
				t.Errorf("%s %s: %v", version, what, err)
			}
		}
		if version == store.AWG2 {
			for _, line := range []string{"S3 = ", "S4 = ", "H1 = ", "H4 = "} {
				if !strings.Contains(conf, line) {
					t.Errorf("the .conf has no %q:\n%s", line, conf)
				}
			}
			if !strings.Contains(conf, "-") || awg.Generation(got["conf"]) != "2.0" {
				t.Errorf("the .conf is not AmneziaWG 2.0:\n%s", conf)
			}
		} else if strings.Contains(conf, "S3 = ") || awg.Generation(got["conf"]) != "1.x" {
			t.Errorf("a 1.x server's .conf has 2.0 keys:\n%s", conf)
		}
	}
}
