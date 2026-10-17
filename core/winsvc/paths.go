// Package winsvc runs the core as a Windows service (LocalSystem) so the VPN
// (TUN) mode works from an app that is not elevated, and cleans up after a
// crashed run.
//
// # How an unelevated app talks to the SYSTEM service, and why
//
// The service serves the same control protocol the app already uses
// (core/control: newline-delimited JSON on a loopback TCP port, first request
// "hello" with a token). Four things keep another local user from driving the
// VPN:
//
//  1. The service listens on 127.0.0.1 only, on a random port chosen at each
//     start, and sends nothing before a valid "hello".
//  2. The token is 256 random bits made at each service start and stored only
//     in the control file.
//  3. The control file lives in %ProgramData%\omnitun\control, a directory with
//     a protected ACL (no inheritance from ProgramData, which lets every user
//     read): SYSTEM and Administrators full control, plus read access for the
//     user accounts named when the service was installed (by default the user
//     who ran the installer). Other users cannot read the token.
//  4. The control file is removed when the service stops, and the token changes
//     on every start, so a stale file reveals nothing.
//
// A named pipe with an ACL would be tighter (other users could not even
// connect), but the app speaks the protocol over dart:io sockets, which cannot
// open a pipe, and the same protocol serves Android and the per-user daemon.
// The residual risk is the one every local VPN client has: code running as an
// allowed user can drive the VPN. The service also runs only the
// configuration builder of this program: a "start" request carries profiles,
// never sing-box JSON or file paths, so a client cannot make SYSTEM read or
// run arbitrary things.
package winsvc

import (
	"os"
	"path/filepath"
)

const (
	// ServiceName is the service's name in the Service Control Manager.
	ServiceName = "OmnitunSvc"
	// DisplayName is shown in services.msc.
	DisplayName = "Wardkeep core"
	// Description is shown in services.msc.
	Description = "Runs the Wardkeep VPN core with system rights, so the VPN mode works from an app that is not run as administrator."
	// ExeName is the service program's file name.
	ExeName = "omnitun-svc.exe"
)

// Layout is where the service keeps its files.
type Layout struct {
	// Common is %ProgramData%\omnitun, writable only by SYSTEM and Administrators.
	Common string
	// ControlDir holds the control file; its ACL admits the allowed users.
	ControlDir string
	// ControlFile is the file the app reads (address, token, pid).
	ControlFile string
	// DataDir is the engine's data directory.
	DataDir string
	// Config is the service's own settings file (Config).
	Config string
	// Log is the service's log file.
	Log string
	// InstallDir is where the installer copies the program, a place only
	// administrators can write: a SYSTEM service must never run a program a
	// normal user can replace.
	InstallDir string
}

// LayoutFrom computes the layout from environment lookups (os.Getenv in
// production, a map in tests).
func LayoutFrom(getenv func(string) string) Layout {
	programData := getenv("ProgramData")
	if programData == "" {
		programData = `C:\ProgramData`
	}
	programFiles := getenv("ProgramFiles")
	if programFiles == "" {
		programFiles = `C:\Program Files`
	}
	common := filepath.Join(programData, "omnitun")
	control := filepath.Join(common, "control")
	return Layout{
		Common:      common,
		ControlDir:  control,
		ControlFile: filepath.Join(control, "control.json"),
		DataDir:     filepath.Join(common, "data"),
		Config:      filepath.Join(common, "config.json"),
		Log:         filepath.Join(common, "service.log"),
		InstallDir:  filepath.Join(programFiles, "Omnitun"),
	}
}

// DefaultLayout is the layout of this machine.
func DefaultLayout() Layout { return LayoutFrom(os.Getenv) }
