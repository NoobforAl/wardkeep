package rvpn

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/wardkeep/core/importer"
	"github.com/NoobforAl/wardkeep/core/logrec"
)

const docLink = "rvpn://k3j9q2xw7a.example.org:443/api/v1/q7w2e9r4t1y6u3i8?v=1" +
	"&ik=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE" +
	"&ixk=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI" +
	"&ixs=AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw" +
	"&spk=BAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ" +
	"&pks=BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQ" +
	"&ikv=1&alt=m8d2p0zr4c.example.net#rVPN"

// TestMain doubles as a fake wardkeep-rvpn: run with RVPN_FAKE set, the test binary speaks the helper's stdout
// contract instead of running tests.
func TestMain(m *testing.M) {
	switch os.Getenv("RVPN_FAKE") {
	case "":
		os.Exit(m.Run())
	case "ok":
		if os.Getenv(envSocksUser) == "" || os.Getenv(envSocksPass) == "" || slices.Contains(os.Args, "--socks-pass") {
			fmt.Println(`{"event":"error","code":"args","message":"no login in the environment"}`)
			os.Exit(2)
		}
		fmt.Println(`{"event":"log","level":"info","msg":"starting"}`)
		fmt.Println(`{"event":"listening","socks":"127.0.0.1:41000"}`)
		fmt.Println(`{"event":"ready","host":1}`)
	case "reject":
		fmt.Println(`{"event":"listening","socks":"127.0.0.1:41001"}`)
		fmt.Println(`{"event":"error","code":"handshake","message":"the server identity does not match the bundle"}`)
	case "die":
		os.Exit(3)
	}
	// Like the real helper: run until stdin closes.
	_, _ = bufio.NewReader(os.Stdin).ReadString(0)
	os.Exit(0)
}

func fake(t *testing.T, mode string, onLog func(logrec.Record)) (*Process, error) {
	t.Helper()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("RVPN_FAKE", mode)
	p, err := importer.ParseLink(docLink)
	if err != nil {
		t.Fatal(err)
	}
	return Start(Config{Bin: exe, DataDir: t.TempDir(), Profile: p, OnLog: onLog})
}

func TestArgs(t *testing.T) {
	p, err := importer.ParseLink(docLink)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	args, err := Args(Config{DataDir: dir, Profile: p, LogLevel: "warn"})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"--data", dir, "--bundle", filepath.Join(dir, "prekey-bundle.json"),
		"--server", "wss://k3j9q2xw7a.example.org:443/api/v1/q7w2e9r4t1y6u3i8", "--socks-port", "0",
		"--alt", "m8d2p0zr4c.example.net", "--log-level", "warn"}
	if !slices.Equal(args, want) {
		t.Fatalf("args =\n%q\nwant\n%q", args, want)
	}
	// The bundle file is rVPN's own format, every key present.
	raw, err := os.ReadFile(filepath.Join(dir, "prekey-bundle.json"))
	if err != nil {
		t.Fatal(err)
	}
	var bundle map[string]any
	if err := json.Unmarshal(raw, &bundle); err != nil {
		t.Fatal(err)
	}
	for _, k := range []string{"identity_key", "identity_x25519_key", "identity_x25519_signature", "signed_prekey",
		"prekey_signature", "one_time_prekey", "identity_key_version", "rotation_signature"} {
		if _, ok := bundle[k]; !ok {
			t.Errorf("bundle file lacks %s", k)
		}
	}
	// No secret of this run is in the bundle or the command line, and the client's own key is never written here.
	if strings.Contains(string(raw), "signing") {
		t.Error("the bundle file holds a private key")
	}
}

// The login is in the environment, once each, never on the command line.
func TestEnvCarriesLogin(t *testing.T) {
	t.Setenv(envSocksUser, "stale")
	env := Env("u1", "p1")
	var users, passes int
	for _, kv := range env {
		switch {
		case strings.HasPrefix(kv, envSocksUser+"="):
			users++
			if kv != envSocksUser+"=u1" {
				t.Errorf("user = %q", kv)
			}
		case strings.HasPrefix(kv, envSocksPass+"="):
			passes++
		}
	}
	if users != 1 || passes != 1 {
		t.Fatalf("%d users, %d passwords in the environment", users, passes)
	}
}

func TestStartReadyAndStop(t *testing.T) {
	var logs []logrec.Record
	proc, err := fake(t, "ok", func(r logrec.Record) { logs = append(logs, r) })
	if err != nil {
		t.Fatal(err)
	}
	if proc.SocksAddr != "127.0.0.1:41000" || len(proc.Username) != 32 || len(proc.Password) != 32 || proc.Username == proc.Password {
		t.Fatalf("proc = %+v", proc)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := proc.Ready(ctx); err != nil {
		t.Fatal(err)
	}
	if !proc.Connected() || proc.LastError() != nil {
		t.Fatal("not connected after ready")
	}
	proc.Stop()
	select {
	case <-proc.Done():
	case <-time.After(5 * time.Second):
		t.Fatal("did not stop")
	}
	if len(logs) == 0 || logs[0].Source != logrec.SourceRVPN || logs[0].Msg != "starting" {
		t.Fatalf("logs = %+v", logs)
	}
}

func TestStartReportsHandshakeError(t *testing.T) {
	proc, err := fake(t, "reject", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer proc.Stop()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	err = proc.Ready(ctx)
	var he *HelperError
	if !errors.As(err, &he) || he.Code != CodeHandshake {
		t.Fatalf("err = %v", err)
	}
	if !strings.HasPrefix(err.Error(), "the rVPN server rejected the handshake") {
		t.Fatalf("message = %q", err)
	}
	if proc.Connected() || proc.LastError() == nil {
		t.Fatal("state does not show the failure")
	}
}

func TestStartExitsEarly(t *testing.T) {
	if _, err := fake(t, "die", nil); err == nil {
		t.Fatal("a helper that exits at once was reported started")
	}
}

func TestFindBinaryEnv(t *testing.T) {
	t.Setenv("WARDKEEP_RVPN_BIN", "/x/wardkeep-rvpn")
	if p, err := FindBinary(); err != nil || p != "/x/wardkeep-rvpn" {
		t.Fatalf("FindBinary = %q, %v", p, err)
	}
}
