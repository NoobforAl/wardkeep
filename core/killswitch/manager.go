package killswitch

import (
	"errors"
	"fmt"
	"os"
	"sync"
)

// SelfApp is the path of the running program, for Options.Apps.
func SelfApp() (string, error) { return os.Executable() }

// ErrUnsupported is returned where there is no kill switch (every system but Windows).
var ErrUnsupported = errors.New("the kill switch is only available on Windows")

// Backend installs rules in the operating system.
type Backend interface {
	// Apply makes rules the only active set. The previous set, if any, is
	// replaced without a gap in which nothing is blocked.
	Apply(rules []Rule) error
	// Remove removes every rule this backend installed. Safe to call twice.
	Remove() error
}

// Manager arms and disarms the kill switch and remembers its state.
type Manager struct {
	backend Backend
	// resolveTun maps an adapter name to its LUID.
	resolveTun func(name string) (uint64, error)
	supported  bool

	mu    sync.Mutex
	armed bool
}

// NewManager returns a manager for the platform's own backend (a stub that
// fails with ErrUnsupported where there is none).
func NewManager() *Manager {
	return &Manager{backend: newBackend(), resolveTun: tunLUID, supported: supported}
}

// NewManagerWith builds a manager from parts (tests).
func NewManagerWith(b Backend, resolveTun func(string) (uint64, error)) *Manager {
	return &Manager{backend: b, resolveTun: resolveTun, supported: true}
}

// Supported reports whether this manager can block anything (false for the
// stub of systems without a kill switch, and for a nil manager).
func (m *Manager) Supported() bool { return m != nil && m.supported }

// Arm installs the rules for o. If tunName is not empty the adapter of that
// name is looked up and its traffic permitted; with an empty name (or o.TunLUID
// already set) the rules cover the time before the tunnel exists. Arming again
// replaces the earlier rules.
func (m *Manager) Arm(o Options, tunName string) error {
	if m == nil {
		return ErrUnsupported
	}
	if o.TunLUID == 0 && tunName != "" {
		luid, err := m.resolveTun(tunName)
		if err != nil {
			return fmt.Errorf("killswitch: find the tunnel adapter %q: %w", tunName, err)
		}
		o.TunLUID = luid
	}
	rules, err := Build(o)
	if err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := m.backend.Apply(rules); err != nil {
		return err
	}
	m.armed = true
	return nil
}

// Disarm removes the rules. Safe to call when not armed.
func (m *Manager) Disarm() error {
	if m == nil {
		return nil
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.armed {
		return nil
	}
	m.armed = false
	return m.backend.Remove()
}

// Armed reports whether rules are installed.
func (m *Manager) Armed() bool {
	if m == nil {
		return false
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.armed
}
