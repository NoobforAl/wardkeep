package main

import (
	"encoding/hex"
	"encoding/json"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/dnscrypt"
	"github.com/NoobforAl/omnitun/server/manager"
)

// The DNSCrypt resolver is off on a new server, `proto enable` turns it on,
// `firewall` then opens its port on both transports, and `link --stamp` gives
// the DNS stamp clients need.
func TestCLIDNSCryptResolver(t *testing.T) {
	dir := tempDir(t)
	if _, err := run(t, dir, "init", "--host", "203.0.113.7"); err != nil {
		t.Fatal(err)
	}
	out, err := run(t, dir, "--json", "proto", "list")
	if err != nil {
		t.Fatal(err)
	}
	var protos []manager.ProtocolInfo
	if err := json.Unmarshal([]byte(out), &protos); err != nil {
		t.Fatal(err)
	}
	var found bool
	for _, p := range protos {
		if p.Key == "dnscrypt" {
			found = true
			if p.Enabled || p.Port != 5443 || p.Transport != "tcp+udp" || p.ShareLink {
				t.Errorf("dnscrypt = %+v, want off, port 5443, tcp+udp, no share link", p)
			}
		}
	}
	if !found {
		t.Fatal("dnscrypt is not in the protocol list")
	}

	// A new server cannot be made with it on: there is no address to listen on yet.
	if _, err := run(t, tempDir(t), "init", "--host", "203.0.113.8", "--protocols", "dnscrypt"); exitCode(err) != 2 {
		t.Fatalf("init --protocols dnscrypt: %v", err)
	}

	// Off: no stamp, and the message says what to do.
	if _, err := run(t, dir, "link", "--stamp"); err == nil || exitCode(err) != 2 || !strings.Contains(err.Error(), "proto enable dnscrypt") {
		t.Fatalf("link --stamp while off: %v", err)
	}
	if out, err := run(t, dir, "firewall", "--dry-run", "--firewall", "none"); err != nil || strings.Contains(out, "5443") {
		t.Fatalf("firewall while off: %v\n%s", err, out)
	}

	// It cannot be switched on without an address to listen on, and never on every interface.
	if _, err := run(t, dir, "proto", "enable", "dnscrypt"); exitCode(err) != 2 || !strings.Contains(err.Error(), "dnscrypt listen") {
		t.Fatalf("enable without a listen address: %v", err)
	}
	for _, wildcard := range []string{"0.0.0.0", "::", "nonsense"} {
		if _, err := run(t, dir, "dnscrypt", "listen", wildcard); exitCode(err) != 2 {
			t.Fatalf("listen %s: %v", wildcard, err)
		}
	}
	if _, err := run(t, dir, "dnscrypt", "allow", "0.0.0.0/0"); exitCode(err) != 2 {
		t.Fatalf("allow of every address: %v", err)
	}
	if _, err := run(t, dir, "dnscrypt", "listen", "10.30.0.1"); err != nil {
		t.Fatal(err)
	}
	if _, err := run(t, dir, "proto", "enable", "dnscrypt"); err != nil {
		t.Fatal(err)
	}
	out, err = run(t, dir, "firewall", "--dry-run", "--firewall", "none")
	if err != nil || !strings.Contains(out, "TCP: ") || !strings.Contains(out, "5443") {
		t.Fatalf("firewall: %v\n%s", err, out)
	}
	for line := range strings.SplitSeq(out, "\n") {
		if strings.HasPrefix(line, "UDP:") && !strings.Contains(line, "5443") {
			t.Errorf("UDP 5443 is not opened: %q", line)
		}
	}

	out, err = run(t, dir, "link", "--stamp")
	if err != nil {
		t.Fatal(err)
	}
	stampText := strings.TrimSpace(out)
	st, err := dnscrypt.ParseDNSCryptStamp(stampText)
	if err != nil {
		t.Fatalf("link --stamp printed %q: %v", stampText, err)
	}
	if st.Addr != "10.30.0.1:5443" || st.Port != 5443 {
		t.Errorf("stamp address %q", st.Addr)
	}
	if !strings.HasPrefix(st.ProviderName, "2.dnscrypt-cert.") {
		t.Errorf("provider %q", st.ProviderName)
	}

	// The key in the stamp is the one `dnscrypt status` shows.
	out, err = run(t, dir, "--json", "dnscrypt", "status")
	if err != nil {
		t.Fatal(err)
	}
	var info manager.DNSCryptInfo
	if err := json.Unmarshal([]byte(out), &info); err != nil {
		t.Fatal(err)
	}
	if info.PublicKey != hex.EncodeToString(st.PublicKey) || info.ProviderName != st.ProviderName || info.Stamp != stampText || !info.Enabled {
		t.Errorf("status %+v does not match the stamp %+v", info, st)
	}
	// The same through `dnscrypt stamp` and the JSON form of link.
	if out, err = run(t, dir, "dnscrypt", "stamp"); err != nil || strings.TrimSpace(out) != stampText {
		t.Errorf("dnscrypt stamp: %v %q", err, out)
	}
	if out, err = run(t, dir, "--json", "link", "--stamp"); err != nil || !strings.Contains(out, stampText) {
		t.Errorf("link --stamp --json: %v %q", err, out)
	}

	// A new key changes the stamp (and only the key).
	if _, err := run(t, dir, "dnscrypt", "rotate-key"); err != nil {
		t.Fatal(err)
	}
	out, _ = run(t, dir, "link", "--stamp")
	st2, err := dnscrypt.ParseDNSCryptStamp(strings.TrimSpace(out))
	if err != nil {
		t.Fatal(err)
	}
	if hex.EncodeToString(st2.PublicKey) == info.PublicKey || st2.ProviderName != st.ProviderName || st2.Addr != st.Addr {
		t.Errorf("after rotate-key: %+v (was %+v)", st2, st)
	}

	// The upstream resolver: public 1.1.1.1 unless set; an IP (with or without a port) or "system".
	if out, _ = run(t, dir, "--json", "dnscrypt", "status"); strings.Contains(out, `"upstream"`) {
		t.Errorf("the default upstream is not empty (the host's resolver must not be the default): %s", out)
	}
	if _, err := run(t, dir, "dnscrypt", "allow", "203.0.113.0/24", "198.51.100.7"); err != nil {
		t.Fatal(err)
	}
	if out, _ = run(t, dir, "--json", "dnscrypt", "status"); !strings.Contains(out, "203.0.113.0/24") || !strings.Contains(out, "198.51.100.7/32") {
		t.Errorf("status after allow: %s", out)
	}
	if _, err := run(t, dir, "dnscrypt", "upstream", "9.9.9.9"); err != nil {
		t.Fatal(err)
	}
	if _, err := run(t, dir, "dnscrypt", "upstream", "not-an-ip"); exitCode(err) != 2 {
		t.Errorf("a name as upstream: %v", err)
	}
	if out, _ = run(t, dir, "--json", "dnscrypt", "status"); !strings.Contains(out, `"upstream": "9.9.9.9"`) {
		t.Errorf("status after upstream:\n%s", out)
	}
	if _, err := run(t, dir, "dnscrypt", "upstream", "system"); err != nil {
		t.Fatal(err)
	}
	if _, err := run(t, dir, "dnscrypt", "upstream"); err != nil {
		t.Fatal(err)
	}

	// The resolver never turns up as a way to connect.
	if _, err := run(t, dir, "user", "add", "alice"); err != nil {
		t.Fatal(err)
	}
	out, err = run(t, dir, "--json", "link", "alice")
	if err != nil || strings.Contains(out, "dnscrypt") || strings.Contains(out, "sdns://") {
		t.Errorf("alice's links mention the DNSCrypt resolver: %v\n%s", err, out)
	}
}
