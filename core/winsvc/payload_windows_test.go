//go:build windows

package winsvc

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func write(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

// A folder under the user's temp directory can be changed by the user: not a
// source an installer may trust. The system folders can only be changed by
// administrators.
func TestWritersOfPathOnRealFolders(t *testing.T) {
	me, err := CurrentUserSID()
	if err != nil {
		t.Fatal(err)
	}
	w, err := writersOfPath(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if !slices.Contains(w, me) {
		t.Errorf("the user's own temp folder must show the user as a writer, got %v", w)
	}
	err = checkAdminOnly(t.TempDir())
	if err == nil || !strings.Contains(err.Error(), "--unsafe-source") {
		t.Errorf("a user-writable folder must be refused with advice, got %v", err)
	}
	for _, dir := range []string{filepath.Join(os.Getenv("SystemRoot"), "System32"), os.Getenv("ProgramFiles")} {
		if w, err := writersOfPath(dir); err != nil || len(w) != 0 {
			t.Errorf("%s: writers %v, err %v (only administrators may change it)", dir, w, err)
		}
		if err := checkAdminOnly(dir); err != nil {
			t.Errorf("%s: %v", dir, err)
		}
	}
}

func TestPlanInstallCopiesOnlyTheAllowlist(t *testing.T) {
	dir := t.TempDir()
	for _, n := range []string{"omnitun-svc.exe", "libcronet.dll", "omnitun-tor.exe", "evil.dll", "version.dll", "flutter_windows.dll", "omnitun-tor-evil.exe", "notes.txt"} {
		write(t, filepath.Join(dir, n), n)
	}
	if err := os.Mkdir(filepath.Join(dir, "libcronet.dll.d"), 0o755); err != nil {
		t.Fatal(err)
	}
	plan, err := planInstall(filepath.Join(dir, "omnitun-svc.exe"))
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]bool{}
	for from, name := range plan.files {
		if filepath.Dir(from) != dir {
			t.Errorf("%s is outside the source folder", from)
		}
		got[name] = true
	}
	want := map[string]bool{ExeName: true, "libcronet.dll": true, "omnitun-tor.exe": true}
	if len(got) != len(want) {
		t.Fatalf("plan = %v, want %v", got, want)
	}
	for n := range want {
		if !got[n] {
			t.Errorf("%s missing from the plan", n)
		}
	}
	// A renamed program is installed under the service's name.
	write(t, filepath.Join(dir, "wardkeep-core.exe"), "x")
	plan, _ = planInstall(filepath.Join(dir, "wardkeep-core.exe"))
	if plan.files[filepath.Join(dir, "wardkeep-core.exe")] != ExeName {
		t.Errorf("renamed program not mapped to %s: %v", ExeName, plan.files)
	}
	if _, err := planInstall(filepath.Join(dir, "missing.exe")); err == nil {
		t.Error("a missing program must be an error")
	}
}

func TestCopyVerified(t *testing.T) {
	dir := t.TempDir()
	src, dst := filepath.Join(dir, "a.bin"), filepath.Join(dir, "out", "b.bin")
	if err := os.Mkdir(filepath.Join(dir, "out"), 0o755); err != nil {
		t.Fatal(err)
	}
	write(t, src, "payload")
	write(t, dst, "old")
	write(t, dst+".new", "stale leftover")
	sum, err := copyVerified(src, dst)
	if err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dst)
	if string(got) != "payload" {
		t.Errorf("destination holds %q", got)
	}
	h := sha256.Sum256([]byte("payload"))
	if want := hex.EncodeToString(h[:]); sum != want {
		t.Errorf("sha256 = %s, want %s", sum, want)
	}
	if _, err := os.Stat(dst + ".new"); err == nil {
		t.Error("temporary file left behind")
	}
}

func TestOpenSourceRefusesLinksAndFolders(t *testing.T) {
	base := t.TempDir()
	target := filepath.Join(base, "target")
	if err := os.Mkdir(target, 0o755); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(target, "f.dll"), "x")
	link := filepath.Join(base, "link")
	if out, err := exec.Command("cmd", "/c", "mklink", "/J", link, target).CombinedOutput(); err != nil {
		t.Skipf("cannot make a junction: %v %s", err, out)
	}
	if f, err := openSource(link); err == nil {
		f.Close()
		t.Error("a junction must be refused")
	}
	if f, err := openSource(target); err == nil {
		f.Close()
		t.Error("a folder must be refused")
	}
	if _, err := copyVerified(link, filepath.Join(base, "out")); err == nil {
		t.Error("copying through a link must fail")
	}
}

// While a file is being installed nobody can change it under us.
func TestOpenSourceBlocksWriters(t *testing.T) {
	f := filepath.Join(t.TempDir(), "p.exe")
	write(t, f, "x")
	in, err := openSource(f)
	if err != nil {
		t.Fatal(err)
	}
	defer in.Close()
	if w, err := os.OpenFile(f, os.O_WRONLY, 0); err == nil {
		w.Close()
		t.Error("the file could be opened for writing while the installer reads it")
	}
	if err := os.Remove(f); err == nil {
		t.Error("the file could be deleted while the installer reads it")
	}
}
