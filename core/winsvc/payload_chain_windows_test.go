//go:build windows

package winsvc

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/sys/windows"
)

// A program in System32 comes from a chain of folders only administrators can
// change (System32, Windows, and the drive root, where users may add folders
// but nothing else): the chain check must accept it. This is read-only.
func TestCheckSourceAcceptsASystemFile(t *testing.T) {
	path := filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe")
	f, err := openSource(path)
	if err != nil {
		t.Skipf("cannot open %s: %v", path, err)
	}
	s := &sourceFile{f: f, name: "cmd.exe", found: path}
	defer s.Close()
	if err := checkSource(s, map[string]bool{}); err != nil {
		t.Errorf("a file from System32 was refused: %v", err)
	}
	if !strings.EqualFold(s.real, path) {
		t.Errorf("real path %q, want %q", s.real, path)
	}
}

func TestCheckSourceRefusesAUserFileAndNamesIt(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "omnitun-svc.exe")
	write(t, path, "x")
	f, err := openSource(path)
	if err != nil {
		t.Fatal(err)
	}
	s := &sourceFile{f: f, name: ExeName, found: path}
	defer s.Close()
	err = checkSource(s, map[string]bool{})
	if err == nil || !strings.Contains(err.Error(), "the file") || !strings.Contains(err.Error(), "--unsafe-source") {
		t.Fatalf("got %v", err)
	}
}

// The folder chain is checked on its own: a user-owned folder, however deep
// below the safe ones, is refused and named; a link anywhere in the chain too.
func TestCheckFolderChain(t *testing.T) {
	base := t.TempDir()
	deep := filepath.Join(base, "a", "b")
	if err := os.MkdirAll(deep, 0o755); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(deep, "f.exe")
	err := checkFolderChain(file, file, map[string]bool{})
	if err == nil || !strings.Contains(err.Error(), "the folder holding the program") || !strings.Contains(err.Error(), deep) {
		t.Errorf("the user's own folder must be named: %v", err)
	}
	// Folders only administrators can change, with their parents up to the drive root.
	for _, p := range []string{
		filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe"),
		filepath.Join(os.Getenv("ProgramFiles"), "x.exe"),
	} {
		if err := checkFolderChain(p, p, map[string]bool{}); err != nil {
			t.Errorf("%s: chain refused: %v", p, err)
		}
	}
	// A link in the chain.
	target := filepath.Join(base, "target")
	os.Mkdir(target, 0o755)
	link := filepath.Join(base, "link")
	if out, err := exec.Command("cmd", "/c", "mklink", "/J", link, target).CombinedOutput(); err != nil {
		t.Skipf("cannot make a junction: %v %s", err, out)
	}
	err = checkFolderChain(filepath.Join(link, "f.exe"), filepath.Join(target, "f.exe"), map[string]bool{})
	if err == nil || !strings.Contains(err.Error(), "is a link") || !strings.Contains(err.Error(), link) {
		t.Errorf("a link in the chain must be refused and named: %v", err)
	}
}

func TestFinalPathOfAnOpenFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "p.exe")
	write(t, path, "x")
	f, err := openSource(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	got, err := finalPath(windows.Handle(f.Fd()))
	if err != nil {
		t.Fatal(err)
	}
	if strings.HasPrefix(got, `\\?\`) || !strings.EqualFold(filepath.Base(got), "p.exe") {
		t.Errorf("final path %q", got)
	}
}

func TestTrimExtendedPrefix(t *testing.T) {
	for in, want := range map[string]string{
		`\\?\C:\x\f.exe`:      `C:\x\f.exe`,
		`\\?\UNC\srv\share\f`: `\\srv\share\f`,
		`C:\plain`:            `C:\plain`,
	} {
		if got := trimExtendedPrefix(in); got != want {
			t.Errorf("trimExtendedPrefix(%q) = %q, want %q", in, got, want)
		}
	}
}

// openPlan holds every file open: a writer or a rename is refused until the
// copy is done, and the unsafe verdict comes from the held handles.
func TestOpenPlanHoldsTheFiles(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "omnitun-svc.exe"), "svc")
	write(t, filepath.Join(dir, "libcronet.dll"), "dll")
	write(t, filepath.Join(dir, "evil.dll"), "evil")
	plan, err := planInstall(filepath.Join(dir, "omnitun-svc.exe"))
	if err != nil {
		t.Fatal(err)
	}
	files, unsafeErr, err := openPlan(plan)
	if err != nil {
		t.Fatal(err)
	}
	defer closeAll(files)
	if len(files) != 2 {
		t.Fatalf("opened %d files, want 2", len(files))
	}
	if unsafeErr == nil {
		t.Error("a user's temp folder must be reported as unsafe")
	}
	for _, s := range files {
		if err := os.Rename(s.found, s.found+".moved"); err == nil {
			t.Errorf("%s could be renamed while held", s.found)
		}
		if w, err := os.OpenFile(s.found, os.O_WRONLY, 0); err == nil {
			w.Close()
			t.Errorf("%s could be written while held", s.found)
		}
	}
	// The install folder is checked too: a user-writable one is refused.
	if _, err := copyProgram(files, t.TempDir(), func(string, ...any) {}); err == nil || !strings.Contains(err.Error(), "install folder is not safe") {
		t.Errorf("copyProgram into a user-writable folder: %v", err)
	}
}
