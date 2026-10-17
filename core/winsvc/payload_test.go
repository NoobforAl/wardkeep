package winsvc

import (
	"slices"
	"strings"
	"testing"
)

func TestPayloadAllowlistIsExactNames(t *testing.T) {
	listing := []string{
		"omnitun-svc.exe", "flutter_windows.dll", "evil.dll", "LIBCRONET.DLL", "libcronet.dll.bak",
		"omnitun-tor.exe", "omnitun-tor-evil.exe", "omnitun-tor2.exe", "version.dll", "wintun.dll", "dbghelp.dll",
	}
	got := payloadCandidates(listing)
	want := []string{"LIBCRONET.DLL", "omnitun-tor.exe"}
	if !slices.Equal(got, want) {
		t.Errorf("candidates = %v, want %v", got, want)
	}
	if got := payloadCandidates(nil); len(got) != 0 {
		t.Errorf("nothing listed, got %v", got)
	}
}

// Names that Windows searches before the system folder when a program loads a
// library are the classic planting spots: none of them may be on the list.
func TestPayloadHasNoSearchOrderHijackNames(t *testing.T) {
	for _, n := range PayloadNames() {
		switch strings.ToLower(n) {
		case "version.dll", "dbghelp.dll", "winmm.dll", "wininet.dll", "dwmapi.dll", "uxtheme.dll", "cryptbase.dll", "wintun.dll":
			t.Errorf("%s must not be installed beside a SYSTEM service", n)
		}
		if strings.ContainsAny(n, "*?\\/") {
			t.Errorf("%q is not an exact file name", n)
		}
	}
	// A caller cannot widen the list through the returned copy.
	l := PayloadNames()
	l[0] = "evil.dll"
	if PayloadNames()[0] == "evil.dll" {
		t.Error("PayloadNames exposes the list itself")
	}
}

const (
	userSID  = "S-1-5-21-1-2-3-1000"
	usersSID = "S-1-5-32-545"
)

func TestWritersOf(t *testing.T) {
	const (
		read  = 0x001200A9 // read & execute
		write = 0x00000002 // FILE_WRITE_DATA
	)
	cases := []struct {
		name    string
		owner   string
		entries []aceEntry
		want    []string
	}{
		{"program files", sidTrustedInstall, []aceEntry{
			{SID: sidTrustedInstall, Mask: genericAll}, {SID: sidSystem, Mask: 0x1F01FF}, {SID: sidAdministrators, Mask: 0x1F01FF},
			{SID: usersSID, Mask: read}, {SID: "S-1-3-0", Mask: genericAll, Flags: aceInheritOnly},
		}, nil},
		{"user can write", sidAdministrators, []aceEntry{{SID: sidSystem, Mask: genericAll}, {SID: userSID, Mask: write}}, []string{userSID}},
		{"users can add subfolders", sidSystem, []aceEntry{{SID: usersSID, Mask: 0x4}}, []string{usersSID}},
		{"can delete", sidSystem, []aceEntry{{SID: usersSID, Mask: accessDelete}}, []string{usersSID}},
		{"can rewrite the list", sidSystem, []aceEntry{{SID: usersSID, Mask: accessWriteDAC}}, []string{usersSID}},
		{"can take ownership", sidSystem, []aceEntry{{SID: usersSID, Mask: accessWriteOwner}}, []string{usersSID}},
		{"owner is a user", userSID, []aceEntry{{SID: sidSystem, Mask: genericAll}}, []string{userSID}},
		{"deny entries are not counted as access", sidSystem, []aceEntry{{SID: usersSID, Mask: genericAll, Deny: true}}, nil},
		{"inherit-only entries do not apply here", sidSystem, []aceEntry{{SID: usersSID, Mask: genericAll, Flags: aceInheritOnly}}, nil},
		{"listed once", sidSystem, []aceEntry{{SID: usersSID, Mask: write}, {SID: usersSID, Mask: accessDelete}}, []string{usersSID}},
		{"empty list", sidSystem, nil, nil},
	}
	for _, c := range cases {
		if got := writersOf(c.owner, c.entries); !slices.Equal(got, c.want) {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
}

func TestUnsafeSourceMessageNamesTheFailingPart(t *testing.T) {
	msg := unsafeSourceError("a folder above the program", "C:\\build", []string{userSID}).Error()
	for _, want := range []string{"a folder above the program", "C:\\build", userSID, "any folder above it", "--unsafe-source"} {
		if !strings.Contains(msg, want) {
			t.Errorf("message lacks %q: %s", want, msg)
		}
	}
}
