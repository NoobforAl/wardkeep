package logs

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"sync"
	"time"
)

const (
	alertsFile = "alerts.json"
	// MaxAlerts is how many alerts are kept; the oldest go first, acknowledged ones before the others.
	MaxAlerts = 200
	// AlertWindow merges a failure into the alert for the same target and code
	// that started less than this long ago, so a failure that repeats is one alert.
	AlertWindow = time.Hour
)

// Alert is a failure nothing handled (a record with notify:true), kept until
// it is acknowledged and beyond, up to MaxAlerts.
type Alert struct {
	ID     string    `json:"id" doc:"Stable id (for acknowledging)"`
	Time   time.Time `json:"time" doc:"When it first happened"`
	Last   time.Time `json:"last" doc:"When it happened last"`
	Count  int       `json:"count" doc:"How often it happened within the window"`
	Level  string    `json:"level" enum:"error,fatal"`
	Source string    `json:"source"`
	Target string    `json:"target,omitempty"`
	Op     string    `json:"op,omitempty"`
	User   string    `json:"user,omitempty"`
	Code   string    `json:"code,omitempty"`
	Msg    string    `json:"msg"`
	Err    string    `json:"err,omitempty"`
	Stack  string    `json:"stack,omitempty"`
	// Acknowledged is set when the admin has seen it.
	Acknowledged bool `json:"acknowledged"`
}

type alertsState struct {
	Next   int     `json:"next"`
	Alerts []Alert `json:"alerts"`
}

// Alerts is the alert store: alerts.json in the data directory, shared by the
// running server (which adds) and the TUI, CLI and web API (which acknowledge).
type Alerts struct {
	dir string
	now func() time.Time
	mu  sync.Mutex
}

// OpenAlerts returns the alert store in dir; the file is created on the first alert.
func OpenAlerts(dir string) *Alerts { return &Alerts{dir: dir, now: time.Now} }

func (a *Alerts) path() string { return filepath.Join(a.dir, alertsFile) }

// load reads the file; a missing or damaged one is empty.
func (a *Alerts) load() alertsState {
	state := alertsState{Next: 1}
	data, err := os.ReadFile(a.path())
	if err != nil || json.Unmarshal(data, &state) != nil {
		return alertsState{Next: 1}
	}
	if state.Next < 1 {
		state.Next = 1
	}
	return state
}

func (a *Alerts) save(state alertsState) error {
	data, err := json.MarshalIndent(state, "", " ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(a.dir, 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(a.dir, alertsFile+".*")
	if err != nil {
		return err
	}
	_, err = tmp.Write(data)
	if closeErr := tmp.Close(); err == nil {
		err = closeErr
	}
	if err == nil {
		err = os.Rename(tmp.Name(), a.path())
	}
	if err != nil {
		os.Remove(tmp.Name())
	}
	return err
}

// update changes the file under a lock that other processes respect too: the
// server adds alerts while the TUI or the CLI acknowledge them.
func (a *Alerts) update(change func(state *alertsState)) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	unlock := a.lockFile()
	defer unlock()
	state := a.load()
	change(&state)
	return a.save(state)
}

// lockFile takes alerts.json.lock, waiting up to a second; a lock older than
// ten seconds was left by a process that died and is taken over.
func (a *Alerts) lockFile() func() {
	lock := a.path() + ".lock"
	_ = os.MkdirAll(a.dir, 0o700) // OpenFile below reports a real problem
	for range 100 {
		file, err := os.OpenFile(lock, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600) //nolint:gosec // G304: a lock file inside the server's own log folder
		if err == nil {
			file.Close()
			return func() { os.Remove(lock) }
		}
		if !errors.Is(err, os.ErrExist) {
			break
		}
		if fi, statErr := os.Stat(lock); statErr == nil && time.Since(fi.ModTime()) > 10*time.Second {
			os.Remove(lock)
			continue
		}
		time.Sleep(10 * time.Millisecond)
	}
	return func() {} // go on without it rather than lose the alert
}

// Add records rec as an alert, or counts it in the alert for the same target
// and code that started within AlertWindow.
func (a *Alerts) Add(rec Record) {
	if a == nil {
		return
	}
	at := rec.Time
	if at.IsZero() {
		at = a.now()
	}
	at = at.UTC()
	_ = a.update(func(state *alertsState) {
		for i := len(state.Alerts) - 1; i >= 0; i-- {
			existing := &state.Alerts[i]
			if existing.Target == rec.Target && existing.Code == rec.Code && existing.Source == rec.Source &&
				at.Sub(existing.Time) < AlertWindow && !at.Before(existing.Time) {
				existing.Count++
				existing.Last = at
				existing.Msg, existing.Err = rec.Msg, rec.Err
				return
			}
		}
		state.Alerts = append(state.Alerts, Alert{
			ID: strconv.Itoa(state.Next), Time: at, Last: at, Count: 1,
			Level: rec.Level, Source: rec.Source, Target: rec.Target, Op: rec.Op, User: rec.User,
			Code: rec.Code, Msg: rec.Msg, Err: rec.Err, Stack: rec.Stack,
		})
		state.Next++
		for len(state.Alerts) > MaxAlerts {
			drop := max(slices.IndexFunc(state.Alerts, func(alert Alert) bool { return alert.Acknowledged }), 0)
			state.Alerts = slices.Delete(state.Alerts, drop, drop+1)
		}
	})
}

// List returns the alerts, newest first.
func (a *Alerts) List() []Alert {
	a.mu.Lock()
	state := a.load()
	a.mu.Unlock()
	slices.Reverse(state.Alerts)
	if state.Alerts == nil {
		state.Alerts = []Alert{}
	}
	return state.Alerts
}

// Unacknowledged counts the alerts not acknowledged yet.
func (a *Alerts) Unacknowledged() int {
	count := 0
	for _, alert := range a.List() {
		if !alert.Acknowledged {
			count++
		}
	}
	return count
}

// Ack acknowledges the alerts with these ids (all of them with all) and
// returns how many changed. Unknown ids are ignored.
func (a *Alerts) Ack(ids []string, all bool) (int, error) {
	changed := 0
	err := a.update(func(state *alertsState) {
		for i := range state.Alerts {
			alert := &state.Alerts[i]
			if !alert.Acknowledged && (all || slices.Contains(ids, alert.ID)) {
				alert.Acknowledged = true
				changed++
			}
		}
	})
	return changed, err
}
