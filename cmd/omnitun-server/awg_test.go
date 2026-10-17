package main

import (
	"encoding/json"
	"testing"

	"github.com/NoobforAl/omnitun/server/manager"
)

func awgVersionInList(t *testing.T, dir string) string {
	t.Helper()
	out, err := run(t, dir, "--json", "proto", "list")
	if err != nil {
		t.Fatal(err)
	}
	var protos []manager.ProtocolInfo
	if err := json.Unmarshal([]byte(out), &protos); err != nil {
		t.Fatal(err)
	}
	for _, p := range protos {
		if p.Key == "amneziawg" {
			return p.AmneziaWGVersion
		}
	}
	t.Fatal("no amneziawg")
	return ""
}

// `init` makes AmneziaWG 2.0 unless told otherwise, and `proto awg-version`
// switches an existing interface.
func TestCLIChoosesTheAmneziaWGVersion(t *testing.T) {
	dir := tempDir(t)
	if _, err := run(t, dir, "init", "--host", "203.0.113.7"); err != nil {
		t.Fatal(err)
	}
	if v := awgVersionInList(t, dir); v != "2.0" {
		t.Fatalf("default = %s", v)
	}
	if _, err := run(t, dir, "proto", "awg-version", "classic"); err != nil {
		t.Fatal(err)
	}
	if v := awgVersionInList(t, dir); v != "1.x" {
		t.Fatalf("after classic = %s", v)
	}
	if _, err := run(t, dir, "proto", "awg-version", "2.0"); err != nil {
		t.Fatal(err)
	}
	if v := awgVersionInList(t, dir); v != "2.0" {
		t.Fatalf("after 2.0 = %s", v)
	}
	if _, err := run(t, dir, "proto", "awg-version", "7"); exitCode(err) != 2 {
		t.Fatalf("a wrong version: code %d", exitCode(err))
	}

	classic := tempDir(t)
	if _, err := run(t, classic, "init", "--host", "203.0.113.7", "--awg-version", "1.x"); err != nil {
		t.Fatal(err)
	}
	if v := awgVersionInList(t, classic); v != "1.x" {
		t.Fatalf("init --awg-version 1.x = %s", v)
	}
	if _, err := run(t, tempDir(t), "init", "--host", "203.0.113.7", "--awg-version", "3"); exitCode(err) != 2 {
		t.Fatalf("init with a wrong version: code %d", exitCode(err))
	}
}

// `init --ipv6` and `proto ipv6 on|off` switch IPv6 inside the tunnels.
func TestCLIIPv6(t *testing.T) {
	ipv6 := func(dir string) bool {
		out, err := run(t, dir, "--json", "status")
		if err != nil {
			t.Fatal(err)
		}
		var info manager.ServerInfo
		if err := json.Unmarshal([]byte(out), &info); err != nil {
			t.Fatal(err)
		}
		return info.IPv6
	}
	dir := tempDir(t)
	if _, err := run(t, dir, "init", "--host", "203.0.113.7"); err != nil {
		t.Fatal(err)
	}
	if ipv6(dir) {
		t.Fatal("a new server has IPv6 on")
	}
	if _, err := run(t, dir, "proto", "ipv6", "on"); err != nil || !ipv6(dir) {
		t.Fatalf("on: %v", err)
	}
	if _, err := run(t, dir, "proto", "ipv6", "off"); err != nil || ipv6(dir) {
		t.Fatalf("off: %v", err)
	}
	if _, err := run(t, dir, "proto", "ipv6", "maybe"); exitCode(err) != 2 {
		t.Fatalf("a wrong word: code %d", exitCode(err))
	}
	withIt := tempDir(t)
	if _, err := run(t, withIt, "init", "--host", "203.0.113.7", "--ipv6"); err != nil || !ipv6(withIt) {
		t.Fatalf("init --ipv6: %v", err)
	}
}
