//go:build with_quic && with_utls && with_wireguard && with_gvisor

package runtime

import (
	"context"
	"strings"
	"testing"
	"time"

	sblog "github.com/sagernet/sing-box/log"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
	"github.com/NoobforAl/omnitun/server/store"
)

func TestParseSingBox(t *testing.T) {
	rec := parseSingBox("\x1b[36mINFO\x1b[0m[0012] [\x1b[38;5;1m3912418562\x1b[0m 15ms] inbound/vless[vless]: [alice] inbound connection from 203.0.113.9:40000")
	if rec.Conn != "3912418562" || rec.Target != "inbound/vless[vless]" || rec.User != "alice" ||
		rec.Msg != "inbound connection from 203.0.113.9:40000" || rec.Source != logs.SourceSingBox {
		t.Fatalf("record = %+v", rec)
	}
	if plain := parseSingBox("ERROR router: something broke: badly"); plain.Target != "router" || plain.Msg != "something broke: badly" || plain.User != "" {
		t.Fatalf("plain = %+v", plain)
	}
	if bare := parseSingBox("no prefix at all"); bare.Target != "" || bare.Msg != "no prefix at all" {
		t.Fatalf("bare = %+v", bare)
	}
}

// sing-box's messages become records at the right level, with client
// addresses only at debug and destinations never.
func TestSingBoxRecords(t *testing.T) {
	dir := tempDir(t)
	file := logs.Open(dir)
	file.SetLevel(logs.LevelDebug)
	file.SetAlerts(logs.OpenAlerts(dir))
	writer := sbLog{file}
	writer.WriteMessage(sblog.LevelInfo, "INFO[0001] [7 1ms] inbound/trojan[trojan]: [bob] inbound connection from 203.0.113.9:40000")
	writer.WriteMessage(sblog.LevelInfo, "INFO[0001] [7 1ms] inbound/trojan[trojan]: [bob] inbound connection to secret.example.com:443")
	writer.WriteMessage(sblog.LevelDebug, "DEBUG[0001] dns: exchange secret.example.com. IN A")
	writer.WriteMessage(sblog.LevelTrace, "TRACE[0001] not kept at debug")
	writer.WriteMessage(sblog.LevelError, "ERROR[0002] inbound/trojan[trojan]: process connection from 203.0.113.9:40000: dial tcp 198.51.100.7:443: i/o timeout")
	writer.WriteMessage(sblog.LevelError, "ERROR[0003] certificate-provider/acme[acme]: could not get certificate from issuer: will retry")
	writer.WriteMessage(sblog.LevelError, "ERROR[0004] certificate-provider/acme[acme]: final attempt; giving up until next scheduled renewal check")
	file.SetLevel(logs.LevelError)
	writer.WriteMessage(sblog.LevelInfo, "INFO[0005] [8 1ms] inbound/trojan[trojan]: dropped by the level")
	file.Close()

	records, _ := logs.Tail(dir, 20)
	if len(records) != 5 {
		t.Fatalf("records = %+v", records)
	}
	from, to, failed, retry, gaveUp := records[0], records[1], records[2], records[3], records[4]
	if from.Level != "debug" || from.Source != "sing-box" || from.User != "bob" || from.Conn != "7" || !strings.Contains(from.Msg, "203.0.113.9") {
		t.Errorf("client connection = %+v", from)
	}
	if to.Msg != "inbound connection to [destination]" {
		t.Errorf("destination = %+v", to)
	}
	if failed.Level != "error" || strings.Contains(failed.Msg, "203.0.113") || strings.Contains(failed.Msg, "198.51.100") || failed.Notify {
		t.Errorf("connection error = %+v", failed)
	}
	if retry.Code != "ACME_FAILED" || retry.Notify {
		t.Errorf("a retried ACME error = %+v", retry)
	}
	if gaveUp.Code != "ACME_FAILED" || !gaveUp.Notify || gaveUp.Op != "acme" {
		t.Errorf("ACME giving up = %+v", gaveUp)
	}
	if alerts := logs.OpenAlerts(dir).List(); len(alerts) != 1 || alerts[0].Code != "ACME_FAILED" {
		t.Errorf("alerts = %+v", alerts)
	}
}

// A panic in the watch loop is a fatal record and an alert; the process goes on.
func TestWatchSurvivesAPanic(t *testing.T) {
	dir := tempDir(t)
	file := logs.Open(dir)
	file.SetAlerts(logs.OpenAlerts(dir))
	srv := &Server{log: file} // no store: the first tick panics
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { srv.Watch(ctx); close(done) }()
	waitFor(t, "the panic record", 10*time.Second, func() bool {
		records, _ := logs.Query(dir, logs.Filter{Level: logs.LevelFatal, Limit: 1})
		return len(records) == 1
	})
	cancel()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("Watch did not end")
	}
	file.Close()
	records, _ := logs.Query(dir, logs.Filter{Level: logs.LevelFatal, Limit: 1})
	if rec := records[0]; !rec.Notify || rec.Code != "PANIC" || rec.Target != "runtime" || rec.Op != "watch" || !strings.Contains(rec.Stack, "watch") {
		t.Fatalf("record = %+v", rec)
	}
	if alerts := logs.OpenAlerts(dir).List(); len(alerts) != 1 || alerts[0].Level != "fatal" {
		t.Fatalf("alerts = %+v", alerts)
	}
}

func initialised(t *testing.T) (*store.Store, *manager.Manager) {
	t.Helper()
	s := store.Open(tempDir(t))
	m := manager.New(s)
	if _, err := m.Init(manager.InitOptions{PublicHost: "127.0.0.1", SubPort: freeTCP(t)}); err != nil {
		t.Fatal(err)
	}
	return s, m
}

// The level and the alerts follow the config; run --log-level wins.
func TestLoggingFollowsTheConfig(t *testing.T) {
	s, m := initialised(t)
	srv := New(s, nil)
	defer srv.log.Close()
	load := func() *store.State {
		st, err := s.Load()
		if err != nil {
			t.Fatal(err)
		}
		return st
	}
	srv.applyLogging(load())
	if srv.log.Level() != logs.DefaultLevel() {
		t.Fatalf("level = %v", srv.log.Level())
	}
	level, off := "warn", false
	m.SetLogging(manager.LoggingPatch{Level: &level, Alerts: &off})
	srv.applyLogging(load())
	if srv.log.Level() != logs.LevelWarn {
		t.Fatalf("level = %v", srv.log.Level())
	}
	srv.failed(true, logs.Record{Msg: "not an alert: alerts are off", Code: "X"}, nil)
	if alerts, _ := m.Alerts(); len(alerts) != 0 {
		t.Fatalf("alerts = %+v", alerts)
	}
	srv.SetLogLevel(logs.LevelTrace)
	srv.applyLogging(load())
	if srv.log.Level() != logs.LevelTrace {
		t.Fatal("the override lost")
	}
	// A level change is nothing the listeners use.
	before := listenerFingerprint(load())
	level = "error"
	m.SetLogging(manager.LoggingPatch{Level: &level})
	if listenerFingerprint(load()) != before {
		t.Fatal("a log level change would restart the listeners")
	}
}

// An ACME domain without a certificate an hour after the start is an alert.
func TestCertificateCheck(t *testing.T) {
	s, m := initialised(t)
	domain := "vpn.example.com"
	if _, err := m.EnableACME(manager.ACMEPatch{Domain: &domain}); err != nil {
		t.Fatal(err)
	}
	srv := New(s, nil)
	defer srv.log.Close()
	srv.log.SetAlerts(logs.OpenAlerts(s.Dir))
	srv.started = time.Now()
	srv.checkCertificate()
	if alerts, _ := m.Alerts(); len(alerts) != 0 {
		t.Fatalf("an alert within the grace time: %+v", alerts)
	}
	srv.started = time.Now().Add(-2 * acmeGrace)
	srv.checkCertificate() // checked a moment ago: waits for the next hour
	if alerts, _ := m.Alerts(); len(alerts) != 0 {
		t.Fatalf("checked twice within the hour: %+v", alerts)
	}
	srv.certChecked = time.Time{}
	srv.checkCertificate()
	if alerts, _ := m.Alerts(); len(alerts) != 1 || alerts[0].Code != "ACME_NOT_ISSUED" || strings.Contains(alerts[0].Msg, domain) {
		t.Fatalf("alerts = %+v", alerts)
	}
}
