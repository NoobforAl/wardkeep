package manager

import (
	"time"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/store"
)

// MaxLogRecords is the most records one log query returns.
const MaxLogRecords = 5000

// LogQuery selects log records.
type LogQuery struct {
	// Level is the lowest level returned ("" = everything).
	Level string
	// Since drops older records when set.
	Since time.Time
	// Limit is how many of the newest records are returned (1..MaxLogRecords).
	Limit int
}

// LogRecords returns the newest records of the server log that match q,
// oldest first.
func (m *Manager) LogRecords(q LogQuery) ([]logs.Record, error) {
	if q.Limit <= 0 || q.Limit > MaxLogRecords {
		return nil, invalid("limit must be between 1 and %d", MaxLogRecords)
	}
	level := logs.LevelTrace
	if q.Level != "" {
		parsed, ok := logs.ParseLevel(q.Level)
		if !ok {
			return nil, invalid("unknown level %q (trace, debug, info, warn, error or fatal)", q.Level)
		}
		level = parsed
	}
	return logs.Query(m.Store.Dir, logs.Filter{Level: level, Since: q.Since, Limit: q.Limit})
}

// alerts is the data directory's alert store.
func (m *Manager) alerts() *logs.Alerts { return logs.OpenAlerts(m.Store.Dir) }

// Alerts returns the alerts (failures nothing handled), newest first.
func (m *Manager) Alerts() ([]logs.Alert, error) { return m.alerts().List(), nil }

// AckAlerts acknowledges the alerts with these ids, or all of them, and
// returns how many changed.
func (m *Manager) AckAlerts(ids []string, all bool) (int, error) {
	if !all && len(ids) == 0 {
		return 0, invalid("name the alert ids, or acknowledge all")
	}
	return m.alerts().Ack(ids, all)
}

// LoggingInfo is the log settings.
type LoggingInfo struct {
	Level        string `json:"level" doc:"The configured level; empty = the default"`
	DefaultLevel string `json:"default_level" doc:"error in release builds, debug in development builds"`
	Effective    string `json:"effective_level" doc:"The level a server started now uses (run --log-level overrides it)"`
	Alerts       bool   `json:"alerts" doc:"Failures nothing handled become alerts"`
}

// LoggingPatch changes the log settings; nil fields stay.
type LoggingPatch struct {
	// Level: "" or "default" returns to the build's default.
	Level  *string `json:"level,omitempty"`
	Alerts *bool   `json:"alerts,omitempty"`
}

func loggingInfo(conf *store.Logging) LoggingInfo {
	effective := logs.DefaultLevel()
	if level, ok := logs.ParseLevel(conf.LevelName()); ok {
		effective = level
	}
	return LoggingInfo{Level: conf.LevelName(), DefaultLevel: logs.DefaultLevel().String(), Effective: effective.String(), Alerts: conf.AlertsEnabled()}
}

// Logging returns the log settings.
func (m *Manager) Logging() (LoggingInfo, error) {
	st, err := m.Store.Load()
	if err != nil {
		return LoggingInfo{}, err
	}
	return loggingInfo(st.Server.Logging), nil
}

// SetLogging changes the log settings; a running server applies them within seconds.
func (m *Manager) SetLogging(patch LoggingPatch) (LoggingInfo, error) {
	var out LoggingInfo
	err := m.Store.Update(func(st *store.State) error {
		conf := store.Logging{}
		if st.Server.Logging != nil {
			conf = *st.Server.Logging
		}
		if patch.Level != nil {
			name := *patch.Level
			if name == "default" {
				name = ""
			}
			if name != "" {
				level, ok := logs.ParseLevel(name)
				if !ok || level == logs.LevelFatal {
					return invalid("unknown level %q (trace, debug, info, warn, error or default)", name)
				}
				name = level.String()
			}
			conf.Level = name
		}
		if patch.Alerts != nil {
			on := *patch.Alerts
			conf.Alerts = &on
			if on {
				conf.Alerts = nil // the default
			}
		}
		st.Server.Logging = &conf
		if conf.Level == "" && conf.Alerts == nil {
			st.Server.Logging = nil
		}
		out = loggingInfo(st.Server.Logging)
		return nil
	})
	return out, err
}
