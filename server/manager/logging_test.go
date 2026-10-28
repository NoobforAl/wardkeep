package manager

import (
	"errors"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/server/logs"
)

func TestLogRecordsAndAlerts(t *testing.T) {
	m := newManager(t)
	lg := logs.Open(m.Store.Dir)
	lg.SetLevel(logs.LevelTrace)
	lg.SetAlerts(logs.OpenAlerts(m.Store.Dir))
	lg.Write("info", "started")
	lg.Log(logs.LevelError, logs.Record{Msg: "trojan did not start", Target: "trojan", Code: "START_FAILED", Notify: true})
	lg.Close()

	all, err := m.LogRecords(LogQuery{Limit: 10})
	if err != nil || len(all) != 2 {
		t.Fatalf("records = %+v %v", all, err)
	}
	errorsOnly, _ := m.LogRecords(LogQuery{Level: "error", Limit: 10})
	if len(errorsOnly) != 1 || errorsOnly[0].Target != "trojan" {
		t.Fatalf("errors = %+v", errorsOnly)
	}
	if future, _ := m.LogRecords(LogQuery{Since: time.Now().Add(time.Hour), Limit: 10}); len(future) != 0 {
		t.Fatalf("since = %+v", future)
	}
	for _, bad := range []LogQuery{{Limit: 0}, {Limit: MaxLogRecords + 1}, {Level: "loud", Limit: 1}} {
		if _, err := m.LogRecords(bad); !errors.Is(err, ErrInvalid) {
			t.Errorf("LogRecords(%+v): %v", bad, err)
		}
	}

	alerts, _ := m.Alerts()
	if len(alerts) != 1 || alerts[0].Code != "START_FAILED" || alerts[0].Acknowledged {
		t.Fatalf("alerts = %+v", alerts)
	}
	if _, err := m.AckAlerts(nil, false); !errors.Is(err, ErrInvalid) {
		t.Fatalf("empty ack: %v", err)
	}
	if changed, err := m.AckAlerts([]string{alerts[0].ID}, false); err != nil || changed != 1 {
		t.Fatalf("ack = %d %v", changed, err)
	}
	if alerts, _ = m.Alerts(); !alerts[0].Acknowledged {
		t.Fatal("not acknowledged")
	}
}

func TestSetLogging(t *testing.T) {
	m := newManager(t)
	info, err := m.Logging()
	if err != nil || info.Level != "" || !info.Alerts || info.Effective != logs.DefaultLevel().String() {
		t.Fatalf("defaults = %+v %v", info, err)
	}
	level, off := "WARN", false
	if info, err = m.SetLogging(LoggingPatch{Level: &level, Alerts: &off}); err != nil || info.Level != "warn" || info.Effective != "warn" || info.Alerts {
		t.Fatalf("set = %+v %v", info, err)
	}
	for _, bad := range []string{"loud", "fatal"} {
		if _, err := m.SetLogging(LoggingPatch{Level: &bad}); !errors.Is(err, ErrInvalid) {
			t.Errorf("level %q: %v", bad, err)
		}
	}
	back, on := "default", true
	if info, _ = m.SetLogging(LoggingPatch{Level: &back, Alerts: &on}); info.Level != "" || !info.Alerts {
		t.Fatalf("back to defaults = %+v", info)
	}
	if st, _ := m.Store.Load(); st.Server.Logging != nil {
		t.Fatalf("defaults are stored as nothing: %+v", st.Server.Logging)
	}
}
