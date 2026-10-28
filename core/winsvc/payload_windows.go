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
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

// aclEntries reads owner and access entries from an open handle.
func aclEntries(h windows.Handle) (owner string, entries []aceEntry, err error) {
	sd, err := windows.GetSecurityInfo(h, windows.SE_FILE_OBJECT, windows.OWNER_SECURITY_INFORMATION|windows.DACL_SECURITY_INFORMATION)
	if err != nil {
		return "", nil, err
	}
	if o, _, err := sd.Owner(); err == nil && o != nil {
		owner = o.String()
	}
	dacl, _, err := sd.DACL()
	if err != nil {
		return "", nil, err
	}
	if dacl == nil {
		// No list at all means everyone has full access.
		return owner, []aceEntry{{SID: "Everyone (no access list)", Mask: genericAll}}, nil
	}
	for i := uint32(0); i < uint32(dacl.AceCount); i++ {
		var ace *windows.ACCESS_ALLOWED_ACE
		if err := windows.GetAce(dacl, i, &ace); err != nil {
			return "", nil, err
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
	return owner, entries, nil
}

// openNode opens a file or folder to read its attributes and access list,
// without following a link.
func openNode(path string) (windows.Handle, uint32, error) {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return 0, 0, err
	}
	handle, err := windows.CreateFile(p, windows.READ_CONTROL|windows.FILE_READ_ATTRIBUTES,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE, nil, windows.OPEN_EXISTING,
		windows.FILE_FLAG_BACKUP_SEMANTICS|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return 0, 0, err
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil {
		windows.CloseHandle(handle)
		return 0, 0, err
	}
	return handle, info.FileAttributes, nil
}

// writersOfPath returns who besides SYSTEM, Administrators and TrustedInstaller
// can change path (see writersOf). It only reads the access list.
func writersOfPath(path string) ([]string, error) {
	handle, _, err := openNode(path)
	if err != nil {
		return nil, err
	}
	defer windows.CloseHandle(handle)
	owner, entries, err := aclEntries(handle)
	if err != nil {
		return nil, err
	}
	return writersOf(owner, entries), nil
}

// checkAdminOnly fails if somebody other than the administrators can change path.
func checkAdminOnly(path string) error {
	writers, err := writersOfPath(path)
	if err != nil {
		return fmt.Errorf("read the access list of %s: %w", path, err)
	}
	if len(writers) > 0 {
		return unsafeSourceError("the folder", path, writers)
	}
	return nil
}

// checkFolderChain checks the folders that contain a source file, given as the
// path it was found at and the real path of the open file: no folder in the
// chain may be a link, and the one holding the file and every one above it up to
// the drive root must not be changeable by non-administrators (the first with
// the full write test, the ones above with ancestorMask: someone who can only
// add entries to C:\ cannot replace the folder below). checked caches folders
// already approved.
func checkFolderChain(found, real string, checked map[string]bool) error {
	for _, dir := range ancestorDirs(found) {
		handle, attrs, err := openNode(dir)
		if err != nil {
			return fmt.Errorf("open %s: %w", dir, err)
		}
		windows.CloseHandle(handle)
		if attrs&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
			return fmt.Errorf("%s (a folder on the way to the program) is a link; use the real folder", dir)
		}
	}
	for i, dir := range ancestorDirs(real) {
		key := strings.ToLower(dir)
		if checked[key] {
			continue
		}
		handle, attrs, err := openNode(dir)
		if err != nil {
			return fmt.Errorf("open %s: %w", dir, err)
		}
		if attrs&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
			windows.CloseHandle(handle)
			return fmt.Errorf("%s (a folder on the way to the program) is a link; use the real folder", dir)
		}
		owner, entries, err := aclEntries(handle)
		windows.CloseHandle(handle)
		if err != nil {
			return fmt.Errorf("read the access list of %s: %w", dir, err)
		}
		what, writers := "the folder holding the program", writersOf(owner, entries)
		if i > 0 {
			what, writers = "a folder above the program", writersOfAncestor(owner, entries)
		}
		if len(writers) > 0 {
			return unsafeSourceError(what, dir, writers)
		}
		checked[key] = true
	}
	return nil
}

// sourceFile is a file to be installed, held open: nobody can write to it, rename
// it or delete it until it is closed (the share mode allows readers only).
type sourceFile struct {
	f     *os.File
	name  string // the file name it gets in the install folder
	found string // the path it was found at
	real  string // its real path (links, substituted drives and 8.3 names resolved)
}

func (s *sourceFile) Close() { s.f.Close() }

func closeAll(files []*sourceFile) {
	for _, s := range files {
		s.Close()
	}
}

// finalPath returns the real path of an open file.
func finalPath(h windows.Handle) (string, error) {
	buf := make([]uint16, 1024)
	for {
		n, err := windows.GetFinalPathNameByHandle(h, &buf[0], uint32(len(buf)), 0 /* FILE_NAME_NORMALIZED | VOLUME_NAME_DOS */)
		if err != nil {
			return "", err
		}
		if int(n) < len(buf) {
			return trimExtendedPrefix(windows.UTF16ToString(buf[:n])), nil
		}
		buf = make([]uint16, n+1)
	}
}

// trimExtendedPrefix turns \\?\C:\x into C:\x and \\?\UNC\s\x into \\s\x.
func trimExtendedPrefix(p string) string {
	if rest, ok := strings.CutPrefix(p, `\\?\UNC\`); ok {
		return `\\` + rest
	}
	return strings.TrimPrefix(p, `\\?\`)
}

// openSource opens a file to be installed. Links are not followed and nobody
// can write to the file while it is open, so what is read is what was checked.
func openSource(path string) (*os.File, error) {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	handle, err := windows.CreateFile(p, windows.GENERIC_READ, windows.FILE_SHARE_READ, nil, windows.OPEN_EXISTING,
		windows.FILE_ATTRIBUTE_NORMAL|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w", path, err)
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil {
		windows.CloseHandle(handle)
		return nil, err
	}
	if info.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		windows.CloseHandle(handle)
		return nil, fmt.Errorf("%s is a link; only real files are installed", path)
	}
	if info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY != 0 {
		windows.CloseHandle(handle)
		return nil, fmt.Errorf("%s is a folder", path)
	}
	return os.NewFile(uintptr(handle), path), nil
}

// checkSource checks an open source file through its own handle: the file's
// access list, its real path and the folders around it.
func checkSource(src *sourceFile, checked map[string]bool) error {
	handle := windows.Handle(src.f.Fd())
	real, err := finalPath(handle)
	if err != nil {
		return fmt.Errorf("find the real path of %s: %w", src.found, err)
	}
	src.real = real
	owner, entries, err := aclEntries(handle)
	if err != nil {
		return fmt.Errorf("read the access list of %s: %w", src.found, err)
	}
	if w := writersOf(owner, entries); len(w) > 0 {
		return unsafeSourceError("the file", real, w)
	}
	return checkFolderChain(src.found, real, checked)
}

// copyVerified copies from (opened as openSource does) to to.
func copyVerified(from, to string) (string, error) {
	in, err := openSource(from)
	if err != nil {
		return "", err
	}
	defer in.Close()
	return copyFrom(in, to)
}

// copyFrom copies the open file in to to, going through a temporary file, and
// checks that what arrived is what was read: the SHA-256 of the bytes read
// from the handle must equal that of the file on disk afterwards. It returns
// the hash.
func copyFrom(in *os.File, to string) (string, error) {
	tmp := to + ".new"
	os.Remove(tmp)
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o755)
	if err != nil {
		return "", err
	}
	hasher := sha256.New()
	_, err = io.Copy(io.MultiWriter(out, hasher), in)
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
	want := hex.EncodeToString(hasher.Sum(nil))
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
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(hasher.Sum(nil)), nil
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

// openPlan opens every planned file once and keeps the handles; the checks
// and, later, the copy and the hash all go through these handles. A source
// that non-administrators could change is reported as unsafe (the files stay
// open so a caller that goes on anyway still copies from the handles it checked);
// err is for everything else. The caller closes the files.
func openPlan(plan installPlan) (files []*sourceFile, unsafeErr error, err error) {
	checked := map[string]bool{}
	for from, name := range plan.files {
		file, err := openSource(from)
		if err != nil {
			closeAll(files)
			return nil, nil, err
		}
		s := &sourceFile{f: file, name: name, found: from}
		files = append(files, s)
		if cerr := checkSource(s, checked); cerr != nil && unsafeErr == nil {
			unsafeErr = cerr
		}
	}
	return files, unsafeErr, nil
}

// copyProgram copies the open source files into dir (a place only
// administrators can write) and returns the installed program's path.
func copyProgram(files []*sourceFile, dir string, logf func(string, ...any)) (string, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	// Whoever can write to the install folder can put code next to the
	// service: it must be closed to normal users (Program Files is).
	if err := checkAdminOnly(dir); err != nil {
		return "", fmt.Errorf("the install folder is not safe: %w", err)
	}
	for _, src := range files {
		to := filepath.Join(dir, src.name)
		if strings.EqualFold(src.real, to) || strings.EqualFold(filepath.Clean(src.found), filepath.Clean(to)) {
			continue // installing from the install folder itself
		}
		sum, err := copyFrom(src.f, to)
		if err != nil {
			return "", err
		}
		logf("copied %s to %s (sha256 %s)", filepath.Base(src.found), dir, sum)
	}
	return filepath.Join(dir, ExeName), nil
}
