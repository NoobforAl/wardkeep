//go:build windows

package winsvc

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"unsafe"

	"golang.org/x/sys/windows"
)

// writersOfPath returns who besides SYSTEM, Administrators and TrustedInstaller
// can change path (see writersOf). It only reads the access list.
func writersOfPath(path string) ([]string, error) {
	sd, err := windows.GetNamedSecurityInfo(path, windows.SE_FILE_OBJECT,
		windows.OWNER_SECURITY_INFORMATION|windows.DACL_SECURITY_INFORMATION)
	if err != nil {
		return nil, err
	}
	owner := ""
	if o, _, err := sd.Owner(); err == nil && o != nil {
		owner = o.String()
	}
	dacl, _, err := sd.DACL()
	if err != nil {
		return nil, err
	}
	if dacl == nil {
		// No list at all means everyone has full access.
		return []string{"Everyone (no access list)"}, nil
	}
	var entries []aceEntry
	for i := uint32(0); i < uint32(dacl.AceCount); i++ {
		var ace *windows.ACCESS_ALLOWED_ACE
		if err := windows.GetAce(dacl, i, &ace); err != nil {
			return nil, err
		}
		switch ace.Header.AceType {
		case windows.ACCESS_ALLOWED_ACE_TYPE, 9: // 9: allowed, with a condition (same layout)
			entries = append(entries, aceEntry{SID: (*windows.SID)(unsafe.Pointer(&ace.SidStart)).String(), Mask: uint32(ace.Mask), Flags: ace.Header.AceFlags})
		case windows.ACCESS_DENIED_ACE_TYPE:
			entries = append(entries, aceEntry{SID: (*windows.SID)(unsafe.Pointer(&ace.SidStart)).String(), Mask: uint32(ace.Mask), Flags: ace.Header.AceFlags, Deny: true})
		default:
			// An entry kind this code does not read: assume the worst.
			entries = append(entries, aceEntry{SID: fmt.Sprintf("(access entry of type %d)", ace.Header.AceType), Mask: genericAll, Flags: ace.Header.AceFlags})
		}
	}
	return writersOf(owner, entries), nil
}

// checkAdminOnly fails if somebody other than the administrators can change path.
func checkAdminOnly(path string) error {
	w, err := writersOfPath(path)
	if err != nil {
		return fmt.Errorf("read the access list of %s: %w", path, err)
	}
	if len(w) > 0 {
		return unsafeSourceError(path, w)
	}
	return nil
}

// openSource opens a file to be installed. Links are not followed and nobody
// can write to the file while it is open (the share mode allows readers only),
// so what is read is what was checked.
func openSource(path string) (*os.File, error) {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	h, err := windows.CreateFile(p, windows.GENERIC_READ, windows.FILE_SHARE_READ, nil, windows.OPEN_EXISTING,
		windows.FILE_ATTRIBUTE_NORMAL|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w", path, err)
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(h, &info); err != nil {
		windows.CloseHandle(h)
		return nil, err
	}
	if info.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		windows.CloseHandle(h)
		return nil, fmt.Errorf("%s is a link; only real files are installed", path)
	}
	if info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY != 0 {
		windows.CloseHandle(h)
		return nil, fmt.Errorf("%s is a folder", path)
	}
	return os.NewFile(uintptr(h), path), nil
}

// copyVerified copies from (opened as openSource does) to to, going through a
// temporary file, and checks that what arrived is what was read: the SHA-256
// of the bytes read from the source handle must equal the SHA-256 of the file
// as it is on disk afterwards. It returns the hash.
func copyVerified(from, to string) (string, error) {
	in, err := openSource(from)
	if err != nil {
		return "", err
	}
	defer in.Close()
	tmp := to + ".new"
	os.Remove(tmp)
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o755)
	if err != nil {
		return "", err
	}
	h := sha256.New()
	_, err = io.Copy(io.MultiWriter(out, h), in)
	if err == nil {
		err = out.Sync()
	}
	if cerr := out.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(tmp)
		return "", err
	}
	want := hex.EncodeToString(h.Sum(nil))
	got, err := fileSHA256(tmp)
	if err != nil || got != want {
		os.Remove(tmp)
		if err == nil {
			err = errors.New("the copy differs from the original")
		}
		return "", fmt.Errorf("verify %s: %w", to, err)
	}
	os.Remove(to)
	if err := os.Rename(tmp, to); err != nil {
		os.Remove(tmp)
		return "", err
	}
	return want, nil
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// installPlan is what install copies: source path -> destination file name.
type installPlan struct {
	exe   string
	files map[string]string
}

// planInstall decides which files are copied from exe's folder: the program
// itself and the allowlisted names, nothing else.
func planInstall(exe string) (installPlan, error) {
	if _, err := os.Stat(exe); err != nil {
		return installPlan{}, err
	}
	plan := installPlan{exe: exe, files: map[string]string{exe: ExeName}}
	src := filepath.Dir(exe)
	entries, err := os.ReadDir(src)
	if err != nil {
		return plan, err
	}
	var listing []string
	for _, e := range entries {
		if !e.IsDir() {
			listing = append(listing, e.Name())
		}
	}
	for _, name := range payloadCandidates(listing) {
		plan.files[filepath.Join(src, name)] = name
	}
	return plan, nil
}

// checkPlanSafe refuses a source that non-administrators can change: the
// folder (they could replace files in it) and every file (they could change
// its contents).
func checkPlanSafe(plan installPlan) error {
	if err := checkAdminOnly(filepath.Dir(plan.exe)); err != nil {
		return err
	}
	for from := range plan.files {
		if err := checkAdminOnly(from); err != nil {
			return err
		}
	}
	return nil
}

// copyProgram copies the planned files into dir (a place only administrators
// can write) and returns the installed program's path.
func copyProgram(plan installPlan, dir string, logf func(string, ...any)) (string, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	// Whoever can write to the install folder can put code next to the
	// service: it must be closed to normal users (Program Files is).
	if err := checkAdminOnly(dir); err != nil {
		return "", fmt.Errorf("the install folder is not safe: %w", err)
	}
	for from, name := range plan.files {
		to := filepath.Join(dir, name)
		if filepath.Clean(from) == filepath.Clean(to) {
			continue // installing from the install folder itself
		}
		sum, err := copyVerified(from, to)
		if err != nil {
			return "", err
		}
		logf("copied %s to %s (sha256 %s)", filepath.Base(from), dir, sum)
	}
	return filepath.Join(dir, ExeName), nil
}
