//go:build !windows

package winsvc

import "errors"

// ErrNotWindows is returned by everything that needs Windows.
var ErrNotWindows = errors.New("the Windows service exists only on Windows")

// ErrNeedsAdmin is returned by commands that change the system when the
// process is not elevated.
var ErrNeedsAdmin = errors.New("needs administrator rights")

// InstallOptions say what to install.
type InstallOptions struct {
	Exe    string
	Users  []string
	NoCopy bool
}

// Status of the service.
type Status struct {
	Installed bool
	State     string
	Path      string
}

func IsService() bool                                    { return false }
func IsElevated() bool                                   { return false }
func RunService(func(stop <-chan struct{}) error) error  { return ErrNotWindows }
func QueryStatus() (Status, error)                       { return Status{}, ErrNotWindows }
func Install(InstallOptions, func(string, ...any)) error { return ErrNotWindows }
func Uninstall(bool, func(string, ...any)) error         { return ErrNotWindows }
func Start(func(string, ...any)) error                   { return ErrNotWindows }
func Stop(func(string, ...any)) error                    { return ErrNotWindows }
func PrepareDirs(Layout, Config) error                   { return ErrNotWindows }
func SecureRoot(Layout) error                            { return ErrNotWindows }
func SecureDir(string, string) error                     { return ErrNotWindows }
func CurrentUserSID() (string, error)                    { return "", ErrNotWindows }
func ResolveSID(string) (string, error)                  { return "", ErrNotWindows }
func CleanupSteps(string) []Step                         { return nil }
