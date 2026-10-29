package runtime

import (
	"sync"
	"time"

	"github.com/NoobforAl/omnitun/server/hostproto"
	"github.com/NoobforAl/omnitun/server/stats"
)

// hostMeters turns the cumulative per-user counts of the host-level servers
// (AmneziaWG) into the tracker's per-user and per-protocol totals, and into
// live connection counts and speed. sing-box's own connections are counted by
// the collector instead.
type hostMeters struct {
	mu   sync.Mutex
	by   map[string]*meterState // by protocol key
	last time.Time              // the previous reading, for the speed
	now  func() time.Time       // tests replace it
}

type meterState struct {
	meter hostproto.Meter
	last  map[string][2]uint64 // what was counted so far, by user: up, down
	live  map[string]stats.Live
}

func (h *hostMeters) clock() time.Time {
	if h.now != nil {
		return h.now()
	}
	return time.Now()
}

// add starts counting a server that has just been started (its counts begin at zero).
func (h *hostMeters) add(key string, source hostproto.Meter) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.by == nil {
		h.by = map[string]*meterState{}
	}
	h.by[key] = &meterState{meter: source, last: map[string][2]uint64{}}
}

// collect adds what every server moved since the last reading.
func (h *hostMeters) collect(tr *stats.Tracker) {
	h.mu.Lock()
	defer h.mu.Unlock()
	now := h.clock()
	dt := now.Sub(h.last).Seconds()
	h.last = now
	if dt < 0.5 {
		dt = 0.5
	}
	for key, st := range h.by {
		h.collectLocked(key, st, tr, dt)
	}
}

// remove takes a last reading of a server that is about to stop, and forgets it.
func (h *hostMeters) remove(key string, tr *stats.Tracker) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if st := h.by[key]; st != nil {
		h.collectLocked(key, st, tr, 1)
		delete(h.by, key)
	}
}

// live is what the host servers' users are doing now, as of the last reading:
// per user, and per protocol the number of connections.
func (h *hostMeters) live() (users map[string]stats.Live, protocols map[string]int) {
	h.mu.Lock()
	defer h.mu.Unlock()
	users, protocols = map[string]stats.Live{}, map[string]int{}
	for key, st := range h.by {
		for user, userLive := range st.live {
			u := users[user]
			u.Connections += userLive.Connections
			u.UpBps += userLive.UpBps
			u.DownBps += userLive.DownBps
			users[user] = u
			protocols[key] += userLive.Connections
		}
	}
	return users, protocols
}

func (h *hostMeters) collectLocked(key string, st *meterState, tr *stats.Tracker, dt float64) {
	live := map[string]stats.Live{}
	for _, usage := range st.meter.Usage() {
		prev := st.last[usage.User]
		du, dd := usage.Up-prev[0], usage.Down-prev[1]
		if usage.Up < prev[0] {
			du = usage.Up
		}
		if usage.Down < prev[1] {
			dd = usage.Down
		}
		st.last[usage.User] = [2]uint64{usage.Up, usage.Down}
		if usage.Sessions > 0 {
			live[usage.User] = stats.Live{Connections: usage.Sessions, UpBps: int64(float64(du) / dt), DownBps: int64(float64(dd) / dt)}
		}
		if tr == nil || (du == 0 && dd == 0) {
			continue
		}
		tr.Add(usage.User, int64(du), int64(dd))
		tr.AddProtocol(key, int64(du), int64(dd))
	}
	st.live = live
}
