package winsvc

import (
	"fmt"
	"path/filepath"
	"slices"
	"strings"
)

// payloadNames are the files, besides the service program itself, that the
// installer copies from the program's folder into Program Files, where they
// are loaded by a program that runs as SYSTEM. It is a list of exact names and
// nothing else: copying "every DLL" of a folder would let anything a user can
// drop there (libcronet.dll is only searched next to the program, the Tor
// client is found next to it) become code that runs with system rights.
//
//   - libcronet.dll: the NaiveProxy outbound's Chromium network stack;
//   - omnitun-tor.exe: the Tor client.
//
// Nothing else is loaded from the program's folder: Wintun is embedded in the
// program and the Flutter app's DLLs belong to the app, not to the service.
var payloadNames = []string{"libcronet.dll", "omnitun-tor.exe"}

// PayloadNames returns a copy of the allowlist.
func PayloadNames() []string { return slices.Clone(payloadNames) }

// payloadCandidates returns the allowlisted names found in listing (the names
// of the files in the source folder), spelled as in the listing, in the
// allowlist's order. Matching is case-insensitive, like the file system.
func payloadCandidates(listing []string) []string {
	var out []string
	for _, want := range payloadNames {
		for _, have := range listing {
			if strings.EqualFold(have, want) {
				out = append(out, have)
				break
			}
		}
	}
	return out
}

// Access masks that let a principal change a file or folder (or its list, or
// its owner, or what it holds).
const (
	fileWriteData     = 0x00000002
	fileAppendData    = 0x00000004
	fileWriteEA       = 0x00000010
	fileDeleteChild   = 0x00000040
	fileWriteAttrs    = 0x00000100
	accessDelete      = 0x00010000
	accessWriteDAC    = 0x00040000
	accessWriteOwner  = 0x00080000
	genericWrite      = 0x40000000
	genericAll        = 0x10000000
	writeMask         = fileWriteData | fileAppendData | fileWriteEA | fileDeleteChild | fileWriteAttrs | accessDelete | accessWriteDAC | accessWriteOwner | genericWrite | genericAll
	aceInheritOnly    = 0x08
	sidTrustedInstall = "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"
)

// aceEntry is one entry of an access list, reduced to what matters here.
type aceEntry struct {
	SID   string
	Mask  uint32
	Flags uint8 // ACE flags (inherit-only entries do not apply to the object itself)
	Deny  bool
}

// adminSIDs may change files in the service's install folder.
var adminSIDs = []string{sidSystem, sidAdministrators, sidTrustedInstall}

// writersOf returns the principals other than SYSTEM, Administrators and
// TrustedInstaller that the list lets change the object, and the owner when
// it is one of them (an owner can always rewrite the list). Deny entries are
// not weighed: a principal with an allow entry is reported even if a deny
// entry would cancel it, which errs on the side of refusing.
func writersOf(owner string, entries []aceEntry) []string {
	return writersWith(owner, entries, writeMask)
}

// ancestorMask is what matters on a folder ABOVE the source: adding a file or
// a subfolder there (write data, append data) does not let anyone replace the
// folder below, so it is not counted; deleting or renaming children, deleting
// the folder, and rewriting its list or owner are.
const ancestorMask = fileDeleteChild | accessDelete | accessWriteDAC | accessWriteOwner | genericWrite | genericAll

// writersOfAncestor is writersOf for a folder above the source.
func writersOfAncestor(owner string, entries []aceEntry) []string {
	return writersWith(owner, entries, ancestorMask)
}

// ancestorDirs returns the folders that contain file, nearest first, up to
// the root of the drive: for C:.exe it is C:, C:, C:\.
func ancestorDirs(file string) []string {
	var out []string
	for d := filepath.Dir(file); ; {
		out = append(out, d)
		parent := filepath.Dir(d)
		if parent == d {
			return out
		}
		d = parent
	}
}

func writersWith(owner string, entries []aceEntry, mask uint32) []string {
	var out []string
	add := func(sid string) {
		if !slices.Contains(adminSIDs, sid) && !slices.Contains(out, sid) {
			out = append(out, sid)
		}
	}
	if owner != "" {
		add(owner)
	}
	for _, e := range entries {
		if e.Deny || e.Flags&aceInheritOnly != 0 || e.Mask&mask == 0 {
			continue
		}
		add(e.SID)
	}
	return out
}

// unsafeSourceError is the message for a source that others can change. what
// says which part of the path failed ("the program file", "the folder it is in",
// "a folder above it").
func unsafeSourceError(what, path string, writers []string) error {
	return fmt.Errorf("%s (%s) can be changed by accounts that are not administrators (%s), and the service would run what they put there as SYSTEM; "+
		"copy omnitun-svc.exe (and libcronet.dll / omnitun-tor.exe if you use them) to a folder where neither it nor any folder above it "+
		"can be changed by anyone but administrators, for example one under Program Files, and run install from there "+
		"(--unsafe-source skips this check; for development only)",
		what, path, strings.Join(writers, ", "))
}
