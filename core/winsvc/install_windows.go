//go:build windows

package winsvc

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

// ErrNeedsAdmin is returned by commands that change the system when the
// process is not elevated.
var ErrNeedsAdmin = errors.New("this needs administrator rights: run it from an elevated terminal (Run as administrator)")

// InstallOptions say what to install.
type InstallOptions struct {
	// Exe is the program to install (the running one by default).
	Exe string
	// Users are the accounts allowed to drive the VPN through the service,
	// as names or SIDs. Empty means the user running the installer.
	Users []string
	// NoCopy registers Exe where it is instead of copying it into the install
	// directory. Only for development: a SYSTEM service must not run a
	// program that a normal user can replace.
	NoCopy bool
	// UnsafeSource installs from a folder that non-administrators can write
	// to. Development only: they could replace what the service runs as SYSTEM.
	UnsafeSource bool
}

// Status of the service.
type Status struct {
	Installed bool
	State     string // "running", "stopped", "starting", "stopping", ...
	Path      string // the registered program, when it could be read
}

func stateName(s svc.State) string {
	switch s {
	case svc.Stopped:
		return "stopped"
	case svc.StartPending:
		return "starting"
	case svc.StopPending:
		return "stopping"
	case svc.Running:
		return "running"
	case svc.ContinuePending:
		return "continuing"
	case svc.PausePending:
		return "pausing"
	case svc.Paused:
		return "paused"
	}
	return fmt.Sprintf("state %d", s)
}

// QueryStatus asks the Service Control Manager. It needs no special rights.
func QueryStatus() (Status, error) {
	m, err := windows.OpenSCManager(nil, nil, windows.SC_MANAGER_CONNECT)
	if err != nil {
		return Status{}, fmt.Errorf("open the service manager: %w", err)
	}
	defer windows.CloseServiceHandle(m)
	name, _ := windows.UTF16PtrFromString(ServiceName)
	h, err := windows.OpenService(m, name, windows.SERVICE_QUERY_STATUS|windows.SERVICE_QUERY_CONFIG)
	if errors.Is(err, windows.ERROR_SERVICE_DOES_NOT_EXIST) {
		return Status{}, nil
	}
	if err != nil {
		return Status{}, fmt.Errorf("open the service: %w", err)
	}
	s := &mgr.Service{Name: ServiceName, Handle: h}
	defer s.Close()
	st, err := s.Query()
	if err != nil {
		return Status{Installed: true}, err
	}
	res := Status{Installed: true, State: stateName(st.State)}
	if cfg, err := s.Config(); err == nil {
		res.Path = cfg.BinaryPathName
	}
	return res, nil
}

func connect() (*mgr.Mgr, error) {
	if !IsElevated() {
		return nil, ErrNeedsAdmin
	}
	return mgr.Connect()
}

// Install registers the service (or updates it), prepares its directories and
// the access list of the control directory, and copies the program into the
// install directory. It does not start the service.
func Install(o InstallOptions, logf func(string, ...any)) error {
	m, err := connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	l := DefaultLayout()

	exe := o.Exe
	if exe == "" {
		if exe, err = os.Executable(); err != nil {
			return err
		}
	}
	if exe, err = filepath.Abs(exe); err != nil {
		return err
	}
	// Decide what is copied, and check where it comes from, before anything on
	// the machine is changed.
	var sources []*sourceFile
	if !o.NoCopy {
		plan, err := planInstall(exe)
		if err != nil {
			return err
		}
		// The files are opened once and stay open until the copy is done.
		var unsafe error
		if sources, unsafe, err = openPlan(plan); err != nil {
			return err
		}
		defer closeAll(sources)
		if unsafe != nil {
			if !o.UnsafeSource {
				return unsafe
			}
			logf("WARNING (--unsafe-source): %v", unsafe)
		}
	}

	// Who may use the service.
	cfg, err := LoadConfig(l.Config)
	if err != nil {
		return err
	}
	users := o.Users
	if len(users) == 0 && len(cfg.AllowedSIDs) == 0 {
		me, err := CurrentUserSID()
		if err != nil {
			return err
		}
		users = []string{me}
	}
	for _, u := range users {
		sid, err := ResolveSID(u)
		if err != nil {
			return err
		}
		logf("allowing the account %s (%s) to use the service", u, sid)
		cfg.Add(sid)
	}
	if err := cfg.Validate(); err != nil {
		return err
	}

	// An installed, running service holds its program open: stop it first.
	wasRunning := false
	if s, err := m.OpenService(ServiceName); err == nil {
		if st, err := s.Query(); err == nil && st.State != svc.Stopped {
			wasRunning = true
			logf("the service is running, stopping it to update it")
			if err := stopAndWait(s, 30*time.Second); err != nil {
				s.Close()
				return err
			}
		}
		s.Close()
	}

	logf("preparing %s", l.Common)
	if err := PrepareDirs(l, cfg); err != nil {
		return err
	}
	if err := SaveConfig(l.Config, cfg); err != nil {
		return err
	}

	target := exe
	if !o.NoCopy {
		if target, err = copyProgram(sources, l.InstallDir, logf); err != nil {
			return err
		}
	} else {
		logf("WARNING: the service will run %s where it is; anyone who can write there can run code as SYSTEM", exe)
	}

	sc := mgr.Config{
		DisplayName:  DisplayName,
		Description:  Description,
		StartType:    mgr.StartAutomatic,
		ErrorControl: mgr.ErrorNormal,
	}
	s, err := m.OpenService(ServiceName)
	if err == nil {
		defer s.Close()
		cur, err := s.Config()
		if err != nil {
			return err
		}
		cur.BinaryPathName = quoted(target) + " service"
		cur.DisplayName, cur.Description, cur.StartType, cur.ErrorControl = sc.DisplayName, sc.Description, sc.StartType, sc.ErrorControl
		if err := s.UpdateConfig(cur); err != nil {
			return fmt.Errorf("update the service: %w", err)
		}
		logf("updated the service %s", ServiceName)
	} else {
		s, err = m.CreateService(ServiceName, target, sc, "service")
		if err != nil {
			return fmt.Errorf("create the service: %w", err)
		}
		defer s.Close()
		logf("created the service %s (starts automatically, runs as LocalSystem)", ServiceName)
	}
	// If the core dies, bring it back: the app reconnects by itself.
	if err := s.SetRecoveryActions([]mgr.RecoveryAction{
		{Type: mgr.ServiceRestart, Delay: 5 * time.Second},
		{Type: mgr.ServiceRestart, Delay: 15 * time.Second},
		{Type: mgr.NoAction},
	}, 24*3600); err != nil {
		logf("could not set the recovery actions: %v", err)
	}
	if wasRunning {
		logf("starting the service again")
		return s.Start("service")
	}
	return nil
}

func quoted(p string) string { return `"` + p + `"` }

func stopAndWait(s *mgr.Service, timeout time.Duration) error {
	st, err := s.Query()
	if err != nil {
		return err
	}
	if st.State != svc.Stopped {
		if st.State != svc.StopPending {
			if st, err = s.Control(svc.Stop); err != nil {
				return fmt.Errorf("stop the service: %w", err)
			}
		}
		deadline := time.Now().Add(timeout)
		for st.State != svc.Stopped {
			if time.Now().After(deadline) {
				return errors.New("the service did not stop in time")
			}
			time.Sleep(300 * time.Millisecond)
			if st, err = s.Query(); err != nil {
				return err
			}
		}
	}
	return nil
}

// Uninstall stops and removes the service and the files it installed. With
// purge it also removes %ProgramData%\omnitun (settings, data, log).
func Uninstall(purge bool, logf func(string, ...any)) error {
	m, err := connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	l := DefaultLayout()
	s, err := m.OpenService(ServiceName)
	switch {
	case err == nil:
		defer s.Close()
		if err := stopAndWait(s, 30*time.Second); err != nil {
			return err
		}
		if err := s.Delete(); err != nil {
			return fmt.Errorf("delete the service: %w", err)
		}
		logf("removed the service %s", ServiceName)
	case errors.Is(err, windows.ERROR_SERVICE_DOES_NOT_EXIST):
		logf("the service is not installed")
	default:
		return err
	}
	// The core removes its own control file when it stops; make sure.
	os.Remove(l.ControlFile)
	removeAll := func(path string) {
		if err := os.RemoveAll(path); err != nil {
			logf("could not remove %s: %v", path, err)
		} else {
			logf("removed %s", path)
		}
	}
	// The running program cannot always be deleted; a failure is only reported.
	if _, err := os.Stat(l.InstallDir); err == nil {
		removeAll(l.InstallDir)
	}
	if purge {
		removeAll(l.Common)
	}
	return nil
}

// Start starts the service and waits until it runs.
func Start(logf func(string, ...any)) error {
	m, err := connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	s, err := m.OpenService(ServiceName)
	if err != nil {
		return fmt.Errorf("the service is not installed: %w", err)
	}
	defer s.Close()
	st, err := s.Query()
	if err != nil {
		return err
	}
	if st.State == svc.Running {
		logf("the service is already running")
		return nil
	}
	if err := s.Start("service"); err != nil {
		return fmt.Errorf("start the service: %w", err)
	}
	deadline := time.Now().Add(30 * time.Second)
	for {
		if st, err = s.Query(); err != nil {
			return err
		}
		if st.State == svc.Running {
			return nil
		}
		if st.State == svc.Stopped || time.Now().After(deadline) {
			return fmt.Errorf("the service did not start (state: %s); see %s", stateName(st.State), DefaultLayout().Log)
		}
		time.Sleep(300 * time.Millisecond)
	}
}

// Stop stops the service and waits until it has stopped.
func Stop(logf func(string, ...any)) error {
	m, err := connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	s, err := m.OpenService(ServiceName)
	if err != nil {
		return fmt.Errorf("the service is not installed: %w", err)
	}
	defer s.Close()
	if err := stopAndWait(s, 30*time.Second); err != nil {
		return err
	}
	logf("the service is stopped")
	return nil
}
