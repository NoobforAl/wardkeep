package winsvc

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NoobforAl/omnitun/core/control"
)

func TestLayoutFrom(t *testing.T) {
	env := map[string]string{"ProgramData": `D:\PD`, "ProgramFiles": `D:\PF`}
	l := LayoutFrom(func(k string) string { return env[k] })
	if l.Common != filepath.Join(`D:\PD`, "omnitun") ||
		l.ControlDir != filepath.Join(l.Common, "control") ||
		l.ControlFile != filepath.Join(l.Common, "control", "control.json") ||
		l.InstallDir != filepath.Join(`D:\PF`, "Omnitun") {
		t.Errorf("layout: %+v", l)
	}
	// The data directory must not be inside the directory the users may read.
	if strings.HasPrefix(l.DataDir, l.ControlDir) {
		t.Error("the data directory is inside the control directory")
	}
	d := LayoutFrom(func(string) string { return "" })
	if !strings.HasPrefix(d.Common, `C:\ProgramData`) || !strings.HasPrefix(d.InstallDir, `C:\Program Files`) {
		t.Errorf("defaults: %+v", d)
	}
}

func TestValidSID(t *testing.T) {
	for _, ok := range []string{"S-1-5-18", "S-1-5-32-544", "S-1-5-21-1004336348-1177238915-682003330-1000"} {
		if !ValidSID(ok) {
			t.Errorf("%s must be valid", ok)
		}
	}
	for _, bad := range []string{"", "SY", "S-1-5", "S-1-5-18)(A;;FA;;;WD", "s-1-5-18", "S-1-5-18 ", "S-1-5-21-x", "S-2-5-18"} {
		if ValidSID(bad) {
			t.Errorf("%q must be invalid", bad)
		}
	}
}

func TestControlDirSDDL(t *testing.T) {
	const user = "S-1-5-21-1004336348-1177238915-682003330-1000"
	got, err := ControlDirSDDL([]string{user, "S-1-5-18", user})
	if err != nil {
		t.Fatal(err)
	}
	// Owner Administrators, protected list, SYSTEM and Administrators full, the user read-only.
	if !strings.HasPrefix(got, "O:BAD:P(") {
		t.Errorf("owner or protection missing: %s", got)
	}
	if !strings.Contains(got, "(A;OICI;FA;;;SY)") || !strings.Contains(got, "(A;OICI;FA;;;BA)") {
		t.Errorf("SYSTEM and Administrators must have full control: %s", got)
	}
	if strings.Count(got, "(A;OICI;FR;;;"+user+")") != 2 {
		t.Errorf("the user must get read access: %s", got)
	}
	if strings.Contains(got, "WD") || strings.Contains(got, "BU") || strings.Contains(got, "AU") {
		t.Errorf("no everyone/users/authenticated entry may appear: %s", got)
	}
	// SYSTEM listed as a user adds no extra entry.
	if strings.Count(got, ";;;SY)") != 1 {
		t.Errorf("duplicate SYSTEM entry: %s", got)
	}
}

func TestControlDirSDDLRejectsBadInput(t *testing.T) {
	for name, sids := range map[string][]string{
		"none":      nil,
		"injection": {"S-1-5-18)(A;;FA;;;WD"},
		"alias":     {"WD"},
		"empty":     {""},
	} {
		if _, err := ControlDirSDDL(sids); err == nil {
			t.Errorf("%s: expected an error", name)
		}
	}
}

func TestRootSDDLHasNoUsers(t *testing.T) {
	if !strings.HasPrefix(RootSDDL, "O:BAD:P(") || strings.Contains(RootSDDL, "WD") || strings.Contains(RootSDDL, "BU") {
		t.Errorf("RootSDDL = %s", RootSDDL)
	}
}

func TestOwnerTrusted(t *testing.T) {
	for sid, want := range map[string]bool{
		"S-1-5-18": true, "S-1-5-32-544": true,
		"S-1-5-21-1-2-3-1000": false, "S-1-1-0": false, "S-1-5-32-545": false, "": false,
	} {
		if OwnerTrusted(sid) != want {
			t.Errorf("OwnerTrusted(%q) = %v", sid, !want)
		}
	}
}

func TestConfigRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	if c, err := LoadConfig(path); err != nil || len(c.AllowedSIDs) != 0 {
		t.Fatalf("missing file: %v %+v", err, c)
	}
	var c Config
	c.Add("S-1-5-21-1-2-3-1000")
	c.Add("S-1-5-21-1-2-3-1000")
	if err := SaveConfig(path, c); err != nil {
		t.Fatal(err)
	}
	got, err := LoadConfig(path)
	if err != nil || len(got.AllowedSIDs) != 1 || got.AllowedSIDs[0] != "S-1-5-21-1-2-3-1000" {
		t.Fatalf("round trip: %v %+v", err, got)
	}
	if err := SaveConfig(path, Config{AllowedSIDs: []string{"bogus"}}); err == nil {
		t.Error("an invalid SID must not be saved")
	}
	if err := SaveConfig(path, Config{}); err == nil {
		t.Error("an empty list must not be saved")
	}
	os.WriteFile(path, []byte("{nope"), 0o600)
	if _, err := LoadConfig(path); err == nil {
		t.Error("a broken file must be an error")
	}
}

func TestRunCleanupRunsEveryStepAndKeepsGoing(t *testing.T) {
	var ran []string
	steps := []Step{
		{Name: "a", Run: func() (string, error) { ran = append(ran, "a"); return "removed x", nil }},
		{Name: "b", Run: func() (string, error) { ran = append(ran, "b"); return "", errors.New("access denied") }},
		{Name: "c", Run: func() (string, error) { ran = append(ran, "c"); panic("boom") }},
		{Name: "d", Run: func() (string, error) { ran = append(ran, "d"); return "", nil }},
	}
	rep := RunCleanup(steps)
	if strings.Join(ran, "") != "abcd" {
		t.Fatalf("ran %v", ran)
	}
	if rep[0].Done != "removed x" || rep[1].Err == nil || rep[2].Err == nil || rep[3].Err != nil {
		t.Errorf("report: %+v", rep)
	}
	err := rep.Err()
	if err == nil || !strings.Contains(err.Error(), "b: access denied") || !strings.Contains(err.Error(), "c: panic: boom") {
		t.Errorf("Err() = %v", err)
	}
	s := rep.String()
	if !strings.Contains(s, "a: removed x") || !strings.Contains(s, "b: FAILED") || !strings.Contains(s, "d: nothing to clean") {
		t.Errorf("String():\n%s", s)
	}
}

func TestRunCleanupIsIdempotent(t *testing.T) {
	left := 1
	step := Step{Name: "x", Run: func() (string, error) {
		if left == 0 {
			return "", nil
		}
		left--
		return "removed", nil
	}}
	if r := RunCleanup([]Step{step}); r[0].Done != "removed" {
		t.Fatal("first run must clean")
	}
	if r := RunCleanup([]Step{step}); r[0].Done != "" || r.Err() != nil {
		t.Fatalf("second run: %+v", r)
	}
}

func startCore(t *testing.T, controlFile string) (token string, stop func()) {
	t.Helper()
	srv, err := control.NewServer(control.ServerConfig{DataDir: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := srv.Listen("127.0.0.1:0"); err != nil {
		t.Fatal(err)
	}
	if err := srv.WriteControlFile(controlFile); err != nil {
		t.Fatal(err)
	}
	go srv.Serve()
	return srv.Token(), func() { srv.Close() }
}

func TestDetect(t *testing.T) {
	file := filepath.Join(t.TempDir(), "control", "control.json")
	ctx := context.Background()
	if _, err := Detect(ctx, file); err == nil {
		t.Fatal("no file: the service is not there")
	}
	_, stop := startCore(t, file)
	cf, err := Detect(ctx, file)
	if err != nil {
		t.Fatalf("running core not detected: %v", err)
	}
	if cf.PID != os.Getpid() || cf.Addr == "" {
		t.Errorf("control file: %+v", cf)
	}
	stop()
	// The file is still there (a crash leaves it) but nothing answers: not detected.
	if _, err := Detect(ctx, file); err == nil {
		t.Fatal("a stale control file must not count as a running service")
	}
}

func TestDetectRejectsWrongTokenAndGarbage(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "control.json")
	_, stop := startCore(t, file)
	defer stop()
	cf, _ := ReadControlFile(file)
	os.WriteFile(file, []byte(`{"addr":"`+cf.Addr+`","token":"wrong","pid":1}`), 0o600)
	if _, err := Detect(context.Background(), file); err == nil {
		t.Error("a wrong token must not be detected")
	}
	for _, body := range []string{"", "not json", `{"addr":"","token":""}`, `{"addr":"127.0.0.1:1"}`} {
		os.WriteFile(file, []byte(body), 0o600)
		if _, err := Detect(context.Background(), file); err == nil {
			t.Errorf("%q must not be detected", body)
		}
	}
}
