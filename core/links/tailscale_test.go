package links

import (
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/profile"
)

func TestTailscaleLinkFields(t *testing.T) {
	p, err := importer.ParseLink("tailscale://tskey-auth-kABC-secret@hs.example.com:8443?hostname=phone&exit=home&routes=1&ephemeral=1#Home")
	if err != nil {
		t.Fatal(err)
	}
	o := p.Tailscale
	if p.Protocol != profile.Tailscale || p.Name != "Home" || p.Password != "tskey-auth-kABC-secret" || o == nil {
		t.Fatalf("profile = %+v", p)
	}
	if o.ControlURL != "https://hs.example.com:8443" || o.Hostname != "phone" || o.ExitNode != "home" || !o.AcceptRoutes || !o.Ephemeral {
		t.Fatalf("options = %+v", o)
	}
	// Tailscale's own control server: no host in the link, no control URL in the profile.
	own, err := importer.ParseLink("tailscale://tskey-auth-kXYZ@/")
	if err != nil || own.Tailscale.ControlURL != "" || own.Name != "Tailscale" {
		t.Fatalf("own = %+v err=%v", own, err)
	}
	// A plain-HTTP Headscale (a lab) needs the scheme said out loud.
	lab, err := importer.ParseLink("headscale://k@lab.test:8080?scheme=http")
	if err != nil || lab.Tailscale.ControlURL != "http://lab.test:8080" {
		t.Fatalf("lab = %+v err=%v", lab, err)
	}
	// Two accounts on one server are two profiles.
	a, _ := importer.ParseLink("tailscale://k1@hs.example.com")
	b, _ := importer.ParseLink("tailscale://k2@hs.example.com")
	if a.ID == b.ID {
		t.Error("different auth keys gave the same profile ID")
	}
}

func TestTailscaleProfilesNeedAKeyAndAGoodServer(t *testing.T) {
	if _, err := importer.ParseLink("tailscale://hs.example.com"); err == nil || !strings.Contains(err.Error(), "auth key") {
		t.Errorf("a link with no key: %v", err)
	}
	for _, v := range []string{"hs.example.com", "ftp://hs.example.com", "https://"} {
		_, err := profile.FromValues(profile.Tailscale, map[string]string{"password": "k", "tailscale.control_url": v})
		if err == nil || !strings.Contains(err.Error(), "control server") {
			t.Errorf("control server %q: %v", v, err)
		}
	}
	if _, err := profile.FromValues(profile.Tailscale, map[string]string{"tailscale.control_url": "https://hs.example.com"}); err == nil ||
		!strings.Contains(err.Error(), "Auth key is required") {
		t.Errorf("no key in the editor: %v", err)
	}
}

// The editor has no server or port for a mesh profile, and its values survive the link.
func TestTailscaleEditorHasNoServerOrPort(t *testing.T) {
	fs, ok := profile.FormFor(profile.Tailscale)
	if !ok {
		t.Fatal("no editor")
	}
	for _, f := range fs {
		if f.Key == "server" || f.Key == "port" {
			t.Errorf("field %q", f.Key)
		}
	}
	p, err := profile.FromValues(profile.Tailscale, map[string]string{"password": "k", "tailscale.control_url": "http://10.0.0.5:8080"})
	if err != nil {
		t.Fatal(err)
	}
	if p.Name != "tailscale" || p.Server != "" || p.Port != 0 {
		t.Fatalf("profile = %+v", p)
	}
	link, err := Export(p)
	if err != nil || !strings.HasPrefix(link, "tailscale://k@10.0.0.5:8080?scheme=http") {
		t.Fatalf("link = %q err=%v", link, err)
	}
}
