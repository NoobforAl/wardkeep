package logrec

import (
	"path"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/NoobforAl/omnitun/core/buildinfo"
)

// The level gate is process-wide: the engine, the control server, sing-box and the helper processes it starts all
// follow it (sing-box and Tor from their next start).
var (
	effective atomic.Int32

	gateMu     sync.Mutex
	explicit   bool
	until      time.Time
	revert     *time.Timer
	generation uint64
)

func init() { effective.Store(int32(DefaultLevel())) }

// DefaultLevel is the level of a build that nobody changed: error in release builds, debug in development builds.
func DefaultLevel() Level {
	if buildinfo.Release() {
		return LevelError
	}
	return LevelDebug
}

// Enabled reports whether records of level are kept. Check it before formatting a message: a level that is off
// costs nothing.
func Enabled(level Level) bool { return int32(level) >= effective.Load() }

// Current is the effective level.
func Current() Level { return Level(effective.Load()) }

// WantCaller reports whether records should carry their caller (debug and trace).
func WantCaller() bool { return Current() <= LevelDebug }

// Get returns the effective level and, when a level was set with an end, when it returns to the default (zero
// otherwise). set reports whether the level was set at all (false: the default).
func Get() (level Level, end time.Time, set bool) {
	gateMu.Lock()
	defer gateMu.Unlock()
	return Current(), until, explicit
}

// SetLevel changes the level; a non-zero end returns it to the default then.
func SetLevel(level Level, end time.Time) {
	gateMu.Lock()
	defer gateMu.Unlock()
	stopRevertLocked()
	explicit, until = true, end
	effective.Store(int32(level))
	if end.IsZero() {
		return
	}
	gen := generation
	revert = time.AfterFunc(time.Until(end), func() {
		gateMu.Lock()
		defer gateMu.Unlock()
		if generation == gen {
			resetLocked()
		}
	})
}

// ResetLevel returns to the default level.
func ResetLevel() {
	gateMu.Lock()
	defer gateMu.Unlock()
	resetLocked()
}

func resetLocked() {
	stopRevertLocked()
	explicit, until = false, time.Time{}
	effective.Store(int32(DefaultLevel()))
}

func stopRevertLocked() {
	generation++
	if revert != nil {
		revert.Stop()
		revert = nil
	}
}

// Caller is "dir/file.go:line" of the function skip frames above the one calling Caller.
func Caller(skip int) string {
	_, file, line, ok := runtime.Caller(skip + 1)
	if !ok {
		return ""
	}
	return shortFile(file) + ":" + strconv.Itoa(line)
}

func shortFile(file string) string {
	file = filepath.ToSlash(file)
	return path.Join(path.Base(path.Dir(file)), path.Base(file))
}
