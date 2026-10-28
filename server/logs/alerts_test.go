package logs

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

func TestAlertsDedupeAckAndPersist(t *testing.T) {
	dir := tempDir(t)
	l := openAt(dir, LevelError)
	store := OpenAlerts(dir)
	l.SetAlerts(store)
	start := time.Date(2026, 10, 16, 18, 0, 0, 0, time.UTC)

	l.Log(LevelError, Record{Time: start, Msg: "trojan did not start", Target: "trojan", Code: "START_FAILED", Notify: true})
	l.Log(LevelError, Record{Time: start.Add(time.Minute), Msg: "trojan did not start again", Target: "trojan", Code: "START_FAILED", Notify: true})
	l.Log(LevelError, Record{Time: start.Add(2 * time.Minute), Msg: "no notify", Target: "trojan", Code: "OTHER"})
	l.Log(LevelError, Record{Time: start.Add(3 * time.Minute), Msg: "dnstt stopped", Target: "dnstt", Code: "STOPPED", Notify: true})
	// Past the window the same failure is a new alert.
	l.Log(LevelError, Record{Time: start.Add(AlertWindow + time.Minute), Msg: "trojan later", Target: "trojan", Code: "START_FAILED", Notify: true})
	// A notify record the log does not keep is no alert either.
	l.SetLevel(LevelFatal)
	l.Log(LevelError, Record{Time: start, Msg: "filtered", Target: "x", Code: "Y", Notify: true})

	list := OpenAlerts(dir).List() // a new store reads the file: what a restart sees
	if len(list) != 3 {
		t.Fatalf("alerts = %+v", list)
	}
	first := list[2]
	if first.ID != "1" || first.Count != 2 || first.Msg != "trojan did not start again" || !first.Time.Equal(start) ||
		!first.Last.Equal(start.Add(time.Minute)) || first.Acknowledged || first.Level != "error" {
		t.Fatalf("first = %+v", first)
	}
	if list[0].Msg != "trojan later" || list[1].Target != "dnstt" {
		t.Fatalf("order = %+v", list)
	}
	if store.Unacknowledged() != 3 {
		t.Fatal("unacknowledged")
	}

	if changed, err := store.Ack([]string{first.ID, "nope"}, false); err != nil || changed != 1 {
		t.Fatalf("ack = %d %v", changed, err)
	}
	if store.Unacknowledged() != 2 {
		t.Fatal("after one ack")
	}
	if changed, _ := store.Ack(nil, true); changed != 2 || store.Unacknowledged() != 0 {
		t.Fatalf("ack all = %d", changed)
	}
	if changed, _ := store.Ack(nil, true); changed != 0 {
		t.Fatal("acknowledging twice changed something")
	}
}

func TestAlertsAreCapped(t *testing.T) {
	dir := tempDir(t)
	store := OpenAlerts(dir)
	start := time.Date(2026, 10, 16, 18, 0, 0, 0, time.UTC)
	add := func(i int) {
		store.Add(Record{Time: start.Add(time.Duration(i) * time.Second), Level: "error", Source: "server", Target: fmt.Sprint("t", i), Code: "C", Msg: fmt.Sprint(i)})
	}
	for i := range MaxAlerts {
		add(i)
	}
	store.Ack([]string{"50"}, false) // an acknowledged one goes before older unacknowledged ones
	add(MaxAlerts)
	add(MaxAlerts + 1)
	list := store.List()
	if len(list) != MaxAlerts {
		t.Fatalf("%d alerts", len(list))
	}
	if list[0].Msg != fmt.Sprint(MaxAlerts+1) || list[len(list)-1].Msg != "1" {
		t.Fatalf("newest %q, oldest %q", list[0].Msg, list[len(list)-1].Msg)
	}
	for _, alert := range list {
		if alert.ID == "50" {
			t.Fatal("the acknowledged alert was kept")
		}
	}
}

// Two writers (the server adding, the TUI acknowledging) do not lose each other's changes.
func TestAlertsConcurrentWriters(t *testing.T) {
	dir := tempDir(t)
	adder, acker := OpenAlerts(dir), OpenAlerts(dir)
	var wg sync.WaitGroup
	for i := range 20 {
		wg.Go(func() { adder.Add(Record{Level: "error", Target: fmt.Sprint(i), Code: "C", Msg: "m"}) })
		wg.Go(func() { acker.Ack(nil, true) })
	}
	wg.Wait()
	if list := acker.List(); len(list) != 20 {
		t.Fatalf("%d alerts", len(list))
	}
}
