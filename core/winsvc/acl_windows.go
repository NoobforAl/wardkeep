//go:build windows

package winsvc

import (
	"errors"
	"fmt"
	"os"
	"slices"
	"unsafe"

	"golang.org/x/sys/windows"
)

// AccessList returns the owner and access-control list of a file or directory as SDDL.
func AccessList(path string) (string, error) {
	sd, err := windows.GetNamedSecurityInfo(path, windows.SE_FILE_OBJECT,
		windows.OWNER_SECURITY_INFORMATION|windows.DACL_SECURITY_INFORMATION)
	if err != nil {
		return "", err
	}
	return sd.String(), nil
}

// SecureDir makes path a directory owned by a trusted account (SYSTEM or
// Administrators) with the owner and access list of sddl, and nothing
// inherited. The parent must exist.
//
// A directory in %ProgramData% can be created by any user, who then owns it
// and may change its access list and swap what is inside, so the directory is
// never simply adopted:
//
//   - it is created with the descriptor already attached (CreateDirectory with
//     security attributes), so there is no moment with an inherited list;
//   - if it already exists, it is opened without following links and refused
//     when it is a reparse point (junction, symbolic link), not a directory, or
//     owned by anybody but SYSTEM or Administrators; the message says to delete it;
//   - the owner and list are then set on that same open handle, so the path
//     cannot be swapped between the check and the change.
func SecureDir(path, sddl string) error { return secureDir(path, sddl, trustedOwners) }

func secureDir(path, sddl string, trusted []string) error {
	sd, err := windows.SecurityDescriptorFromString(sddl)
	if err != nil {
		return fmt.Errorf("access list %q: %w", sddl, err)
	}
	owner, _, err := sd.Owner()
	if err != nil || owner == nil {
		return fmt.Errorf("access list %q names no owner", sddl)
	}
	if !slices.Contains(trusted, owner.String()) {
		return fmt.Errorf("refusing to make %s the owner of %s", owner, path)
	}
	dacl, _, err := sd.DACL()
	if err != nil {
		return err
	}
	p16, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	sa := &windows.SecurityAttributes{Length: uint32(unsafe.Sizeof(windows.SecurityAttributes{})), SecurityDescriptor: sd}
	if err := windows.CreateDirectory(p16, sa); err != nil && !errors.Is(err, windows.ERROR_ALREADY_EXISTS) {
		return fmt.Errorf("create %s: %w", path, err)
	}

	handle, err := windows.CreateFile(p16, windows.READ_CONTROL|windows.WRITE_DAC|windows.WRITE_OWNER,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE, nil, windows.OPEN_EXISTING,
		windows.FILE_FLAG_BACKUP_SEMANTICS|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return fmt.Errorf("open %s: %w", path, err)
	}
	defer windows.CloseHandle(handle)
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil {
		return err
	}
	if err := checkDirAttributes(path, info.FileAttributes); err != nil {
		return err
	}
	cur, err := windows.GetSecurityInfo(handle, windows.SE_FILE_OBJECT, windows.OWNER_SECURITY_INFORMATION)
	if err != nil {
		return err
	}
	curOwner, _, err := cur.Owner()
	if err != nil || curOwner == nil {
		return fmt.Errorf("cannot read the owner of %s", path)
	}
	if !slices.Contains(trusted, curOwner.String()) {
		return fmt.Errorf("%s exists and is owned by %s, not by SYSTEM or Administrators; delete it and try again", path, curOwner)
	}
	return windows.SetSecurityInfo(handle, windows.SE_FILE_OBJECT,
		windows.OWNER_SECURITY_INFORMATION|windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION,
		owner, nil, dacl, nil)
}

// checkDirAttributes refuses anything but a plain directory.
func checkDirAttributes(path string, attrs uint32) error {
	if attrs&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		return fmt.Errorf("%s is a link (junction or symbolic link); delete it and try again", path)
	}
	if attrs&windows.FILE_ATTRIBUTE_DIRECTORY == 0 {
		return fmt.Errorf("%s exists and is not a directory; delete it and try again", path)
	}
	return nil
}

// SecureRoot prepares %ProgramData%\omnitun. It is the first thing the
// service and the installer do, before anything is written there.
func SecureRoot(l Layout) error {
	if err := SecureDir(l.Common, RootSDDL); err != nil {
		return fmt.Errorf("protect %s: %w", l.Common, err)
	}
	return nil
}

// PrepareDirs creates the service's directories with their owner and access
// lists. The order matters: a directory is locked before anything secret is
// put in it, and the parent before its children.
func PrepareDirs(layout Layout, cfg Config) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	controlSDDL, err := ControlDirSDDL(cfg.AllowedSIDs)
	if err != nil {
		return err
	}
	if err := SecureRoot(layout); err != nil {
		return err
	}
	for _, dir := range []struct{ path, sddl string }{
		{layout.DataDir, RootSDDL},
		{layout.ControlDir, controlSDDL},
	} {
		if err := SecureDir(dir.path, dir.sddl); err != nil {
			return fmt.Errorf("protect %s: %w", dir.path, err)
		}
	}
	// Whatever is left in the control directory is stale (a crashed run) or
	// planted; only the service may write here, so removing it is safe.
	for _, f := range []string{layout.ControlFile, layout.ControlFile + ".tmp"} {
		if err := os.Remove(f); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	return nil
}

// CurrentUserSID is the account running this process.
func CurrentUserSID() (string, error) {
	u, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		return "", err
	}
	return u.User.Sid.String(), nil
}

// ResolveSID turns an account name ("DOMAIN\\name", "name") or a SID string
// into a SID string.
func ResolveSID(account string) (string, error) {
	if ValidSID(account) {
		return account, nil
	}
	sid, _, _, err := windows.LookupSID("", account)
	if err != nil {
		return "", fmt.Errorf("unknown account %q: %w", account, err)
	}
	return sid.String(), nil
}

// IsElevated reports whether this process has administrator rights.
func IsElevated() bool { return windows.GetCurrentProcessToken().IsElevated() }
