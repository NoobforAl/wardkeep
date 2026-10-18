//go:build windows

package winsvc

import (
	"crypto/md5"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"golang.org/x/sys/windows"
)

func TestWintunGUIDIsTheMD5OfWintunAndTheName(t *testing.T) {
	sum := md5.Sum([]byte("wintunWardkeep"))
	g := WintunGUID("Wardkeep")
	got := [16]byte{}
	copy(got[:4], []byte{byte(g.Data1), byte(g.Data1 >> 8), byte(g.Data1 >> 16), byte(g.Data1 >> 24)})
	copy(got[4:6], []byte{byte(g.Data2), byte(g.Data2 >> 8)})
	copy(got[6:8], []byte{byte(g.Data3), byte(g.Data3 >> 8)})
	copy(got[8:], g.Data4[:])
	if got != sum {
		t.Errorf("GUID bytes %x, want the MD5 %x", got, sum)
	}
	if WintunGUID("Wardkeep") == WintunGUID("Other") {
		t.Error("different names must give different GUIDs")
	}
	if s := g.String(); !strings.HasPrefix(s, "{") || !strings.HasSuffix(s, "}") {
		t.Errorf("GUID string %q has no braces (the registry value has them)", s)
	}
}

func TestSDDLsParse(t *testing.T) {
	me, err := CurrentUserSID()
	if err != nil {
		t.Fatal(err)
	}
	control, err := ControlDirSDDL([]string{me})
	if err != nil {
		t.Fatal(err)
	}
	for name, sddl := range map[string]string{"root": RootSDDL, "control": control} {
		sd, err := windows.SecurityDescriptorFromString(sddl)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		owner, _, err := sd.Owner()
		if err != nil || owner.String() != "S-1-5-32-544" {
			t.Errorf("%s: owner %v %v", name, owner, err)
		}
		ctl, _, _ := sd.Control()
		if ctl&windows.SE_DACL_PROTECTED == 0 {
			t.Errorf("%s: the list must be protected from inheritance", name)
		}
		dacl, _, err := sd.DACL()
		if err != nil || dacl == nil {
			t.Fatalf("%s: %v", name, err)
		}
		want := map[string]int{"root": 2, "control": 3}[name]
		if int(dacl.AceCount) != want {
			t.Errorf("%s: %d entries, want %d", name, dacl.AceCount, want)
		}
	}
}

// ownSDDL is an owner and list for tests: the current user instead of
// Administrators, because a normal user cannot make Administrators the owner.
func ownSDDL(t *testing.T) (sddl, sid string) {
	t.Helper()
	me, err := CurrentUserSID()
	if err != nil {
		t.Fatal(err)
	}
	return "O:" + me + "D:P(A;OICI;FA;;;" + me + ")(A;OICI;FR;;;S-1-5-32-545)", me
}

// ownerOf is the owner of path as a SID string. AccessList writes the well-known accounts by their short names
// (BA, SY, and LA for the local Administrator account, which is what a CI machine's user is), so the text
// is turned back into a SID before it is compared with anything.
func ownerOf(t *testing.T, path string) string {
	t.Helper()
	got, err := AccessList(path)
	if err != nil {
		t.Fatal(err)
	}
	// O:<owner>[G:<group>][D:<access list>]: the owner is what stands before the group or the list.
	m := regexp.MustCompile(`^O:(.+?)(?:G:|D:|$)`).FindStringSubmatch(got)
	if m == nil {
		t.Fatalf("no owner in %s", got)
	}
	token := m[1]
	sid, err := windows.StringToSid(token)
	if err != nil {
		t.Fatalf("owner %q of %s is not a SID: %v", token, path, err)
	}
	return sid.String()
}

func TestSecureDirCreatesWithOwnerAndProtectedList(t *testing.T) {
	sddl, me := ownSDDL(t)
	dir := filepath.Join(t.TempDir(), "secured")
	if err := secureDir(dir, sddl, []string{me}); err != nil {
		t.Fatal(err)
	}
	got, err := AccessList(dir)
	if err != nil {
		t.Fatal(err)
	}
	if ownerOf(t, dir) != me || !strings.Contains(got, "D:P") {
		t.Errorf("owner or protection missing: %s", got)
	}
	// Only our two entries: nothing inherited from the temp directory.
	if strings.Count(got, "(A;") != 2 {
		t.Errorf("unexpected entries: %s", got)
	}
	// Idempotent.
	if err := secureDir(dir, sddl, []string{me}); err != nil {
		t.Fatalf("second run: %v", err)
	}
}

func TestSecureDirRefusesATrustedOwnerItIsNot(t *testing.T) {
	// The real rule: only SYSTEM or Administrators may own the directory. The
	// test user is neither, so asking for Administrators as owner must be
	// refused when the directory is ours.
	_, me := ownSDDL(t)
	if OwnerTrusted(me) {
		t.Skip("running as an account that is trusted")
	}
	dir := filepath.Join(t.TempDir(), "preexisting")
	if err := os.Mkdir(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	// An administrator's token makes Administrators the owner of what it creates (a CI machine's user is one):
	// that directory is trusted, rightly, and there is no refusal to look for.
	if owner := ownerOf(t, dir); OwnerTrusted(owner) {
		t.Skipf("directories made by this account are owned by %s, which is trusted", owner)
	}
	before, _ := AccessList(dir)
	err := SecureDir(dir, RootSDDL)
	if err == nil || !strings.Contains(err.Error(), "owned by") {
		t.Fatalf("a directory a normal user made must be refused, got %v", err)
	}
	if after, _ := AccessList(dir); after != before {
		t.Errorf("the refused directory was changed:\nbefore %s\nafter  %s", before, after)
	}
}

func TestSecureDirRefusesUntrustedOwnerInTheList(t *testing.T) {
	sddl, me := ownSDDL(t)
	if err := secureDir(filepath.Join(t.TempDir(), "x"), sddl, []string{"S-1-5-18"}); err == nil {
		t.Error("an owner outside the trusted set must be refused before anything is created")
	}
	_ = me
}

func TestSecureDirRefusesAJunction(t *testing.T) {
	sddl, me := ownSDDL(t)
	base := t.TempDir()
	target := filepath.Join(base, "target")
	if err := os.Mkdir(target, 0o700); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(base, "link")
	if out, err := exec.Command("cmd", "/c", "mklink", "/J", link, target).CombinedOutput(); err != nil {
		t.Skipf("cannot make a junction here: %v %s", err, out)
	}
	before, _ := AccessList(target)
	err := secureDir(link, sddl, []string{me})
	if err == nil || !strings.Contains(err.Error(), "link") {
		t.Fatalf("a junction must be refused, got %v", err)
	}
	if after, _ := AccessList(target); after != before {
		t.Errorf("the junction's target was changed:\nbefore %s\nafter  %s", before, after)
	}
}

func TestSecureDirRefusesAFile(t *testing.T) {
	sddl, me := ownSDDL(t)
	f := filepath.Join(t.TempDir(), "file")
	if err := os.WriteFile(f, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := secureDir(f, sddl, []string{me}); err == nil || !strings.Contains(err.Error(), "not a directory") {
		t.Fatalf("a file must be refused, got %v", err)
	}
}

func TestCheckDirAttributes(t *testing.T) {
	if err := checkDirAttributes("p", windows.FILE_ATTRIBUTE_DIRECTORY); err != nil {
		t.Error(err)
	}
	if err := checkDirAttributes("p", windows.FILE_ATTRIBUTE_DIRECTORY|windows.FILE_ATTRIBUTE_REPARSE_POINT); err == nil {
		t.Error("a reparse point must be refused")
	}
	if err := checkDirAttributes("p", windows.FILE_ATTRIBUTE_NORMAL); err == nil {
		t.Error("a file must be refused")
	}
}

func TestSecureDirNeedsAnExistingParent(t *testing.T) {
	sddl, me := ownSDDL(t)
	if err := secureDir(filepath.Join(t.TempDir(), "no", "such", "parent"), sddl, []string{me}); err == nil {
		t.Error("a missing parent must be an error, not silently created with an inherited list")
	}
}

// The reading parts of the cleanup need no rights and must not touch anything
// that is not ours.
func TestListWintunAdaptersAndCleanupOfAnAdapterThatIsNotThere(t *testing.T) {
	list, err := ListWintunAdapters()
	if err != nil {
		t.Fatalf("listing needs no rights: %v", err)
	}
	t.Logf("%d Wintun adapter(s) on this machine", len(list))
	const name = "omnitun-test-no-such-adapter-4417"
	want := WintunGUID(name).String()
	for _, a := range list {
		if strings.EqualFold(a.NetCfgInstanceID, want) {
			t.Fatalf("an adapter with the test name exists: %+v", a)
		}
	}
	done, err := removeAdapter(name)
	if err != nil || done != "" {
		t.Errorf("nothing to clean, got %q, %v", done, err)
	}
}

func TestQueryStatusNeedsNoRights(t *testing.T) {
	st, err := QueryStatus()
	if err != nil {
		t.Fatalf("status: %v", err)
	}
	t.Logf("service installed=%v state=%q", st.Installed, st.State)
	if !st.Installed && (st.State != "" || st.Path != "") {
		t.Errorf("not installed but %+v", st)
	}
}

func TestInstallAndStartNeedAdmin(t *testing.T) {
	if IsElevated() {
		t.Skip("elevated: would really install")
	}
	logf := func(string, ...any) {}
	if err := Install(InstallOptions{}, logf); err != ErrNeedsAdmin {
		t.Errorf("Install: %v", err)
	}
	if err := Uninstall(false, logf); err != ErrNeedsAdmin {
		t.Errorf("Uninstall: %v", err)
	}
	if err := Start(logf); err != ErrNeedsAdmin {
		t.Errorf("Start: %v", err)
	}
	if err := Stop(logf); err != ErrNeedsAdmin {
		t.Errorf("Stop: %v", err)
	}
}
