// Command torbench measures the Tor client: it starts wardkeep-tor (through core/tor, as the engine does, with
// the pluggable transports in this process), times the bootstrap, sends traffic through its SOCKS port (a new
// connection per request, so streams open and close all the time), idles, stops it and reports. The Go side
// (the transports) is profiled here: CPU and heap profiles, and the goroutines left after the stop. The Rust
// process is measured from outside (scripts sample it by name); build it with --features dhat-heap for its heap.
//
//	go run ./tools/torbench -kind obfs4 -bin target/profiling/wardkeep-tor.exe -out bench/obfs4
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"runtime/pprof"
	"slices"
	"sync"
	"sync/atomic"
	"time"

	"github.com/NoobforAl/wardkeep/core/logrec"
	"github.com/NoobforAl/wardkeep/core/tor"
)

type phaseStats struct {
	Requests  int64   `json:"requests"`
	Errors    int64   `json:"errors"`
	Bytes     int64   `json:"bytes"`
	Seconds   float64 `json:"seconds"`
	MbitPerS  float64 `json:"mbit_per_s"`
	P50Millis int64   `json:"p50_ms"`
	P90Millis int64   `json:"p90_ms"`
	MaxMillis int64   `json:"max_ms"`
	FirstErr  string  `json:"first_error,omitempty"`
}

type report struct {
	Kind            string           `json:"kind"`
	Level           string           `json:"level"`
	Bridges         int              `json:"bridges"`
	BootstrapMillis int64            `json:"bootstrap_ms"`
	CircuitMillis   int64            `json:"circuit_check_ms"`
	Failed          string           `json:"failed,omitempty"`
	Small           phaseStats       `json:"small_requests"`
	Large           phaseStats       `json:"large_requests"`
	LogRecords      map[string]int64 `json:"log_records"`
	LogBytes        int64            `json:"log_bytes"`
	Goroutines      struct {
		Before, Running, AfterStop int
	} `json:"goroutines"`
	GoHeap struct {
		PeakInUseMB, AfterStopMB, TotalAllocMB float64
		GCs                                    uint32
	} `json:"go_heap"`
	StopMillis int64 `json:"stop_ms"`
}

func main() {
	kind := flag.String("kind", "direct", "direct, or a built-in bridge kind: obfs4, snowflake")
	bin := flag.String("bin", "", "wardkeep-tor executable")
	level := flag.String("level", "trace", "wardkeep-tor --log-level")
	out := flag.String("out", "bench", "output folder")
	bootTimeout := flag.Duration("boot-timeout", 6*time.Minute, "give up on the bootstrap after this")
	load := flag.Duration("load", 2*time.Minute, "how long to send traffic")
	workers := flag.Int("workers", 4, "parallel requests")
	idle := flag.Duration("idle", 60*time.Second, "idle time after the load, before the stop")
	smallURL := flag.String("small", "https://check.torproject.org/api/ip", "small request")
	largeURL := flag.String("large", "https://speed.cloudflare.com/__down?bytes=1000000", "large request (1 MB)")
	flag.Parse()
	if err := os.MkdirAll(*out, 0o750); err != nil {
		fail(err)
	}
	cpu, err := os.Create(filepath.Join(*out, "go-cpu.pprof"))
	if err != nil {
		fail(err)
	}
	_ = pprof.StartCPUProfile(cpu)

	rep := report{Kind: *kind, Level: *level, LogRecords: map[string]int64{}}
	rep.Goroutines.Before = runtime.NumGoroutine()
	var bridges []string
	if *kind != "direct" {
		bridges = tor.Builtin(*kind)
	}
	rep.Bridges = len(bridges)

	logFile, err := os.Create(filepath.Join(*out, "tor-log.jsonl"))
	if err != nil {
		fail(err)
	}
	var logMu sync.Mutex
	var peak atomic.Uint64
	stopPeak := watchHeap(&peak)
	data, _ := os.MkdirTemp("", "torbench-")
	defer os.RemoveAll(data)
	tor.SetTransportLog(func(line string) { fmt.Fprintln(os.Stderr, "transport:", line) })

	start := time.Now()
	proc, err := tor.Start(tor.Config{
		Bin: *bin, DataDir: data, Bridges: bridges, LogLevel: *level,
		OnBootstrap: func(pct int, status string) {
			fmt.Fprintf(os.Stderr, "%6.1fs bootstrap %d%% %s\n", time.Since(start).Seconds(), pct, status)
		},
		OnLog: func(rec logrec.Record) {
			line, _ := json.Marshal(rec)
			logMu.Lock()
			rep.LogRecords[rec.Level.String()]++
			rep.LogBytes += int64(len(line)) + 1
			_, _ = logFile.Write(append(line, '\n'))
			logMu.Unlock()
		},
	})
	if err != nil {
		fail(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), *bootTimeout)
	err = proc.Ready(ctx)
	cancel()
	rep.BootstrapMillis = time.Since(start).Milliseconds()
	if err == nil {
		t := time.Now()
		cctx, ccancel := context.WithTimeout(context.Background(), 90*time.Second)
		err = tor.CheckCircuit(cctx, proc.SocksAddr)
		ccancel()
		rep.CircuitMillis = time.Since(t).Milliseconds()
	}
	if err != nil {
		rep.Failed = err.Error()
		fmt.Fprintln(os.Stderr, "not ready:", err)
	} else {
		fmt.Fprintf(os.Stderr, "ready in %.1fs; load for %s\n", time.Since(start).Seconds(), *load)
		rep.Goroutines.Running = runtime.NumGoroutine()
		rep.Small, rep.Large = runLoad(proc.SocksAddr, *smallURL, *largeURL, *load, *workers)
		fmt.Fprintf(os.Stderr, "load done; idle for %s\n", *idle)
		time.Sleep(*idle)
	}

	t := time.Now()
	proc.Stop()
	<-proc.Done()
	rep.StopMillis = time.Since(t).Milliseconds()
	time.Sleep(2 * time.Second) // let the transports' goroutines see their listeners close
	stopPeak()
	runtime.GC()
	rep.Goroutines.AfterStop = runtime.NumGoroutine()
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	rep.GoHeap.PeakInUseMB = mb(peak.Load())
	rep.GoHeap.AfterStopMB = mb(ms.HeapInuse)
	rep.GoHeap.TotalAllocMB = mb(ms.TotalAlloc)
	rep.GoHeap.GCs = ms.NumGC
	pprof.StopCPUProfile()
	_ = cpu.Close()
	if f, err := os.Create(filepath.Join(*out, "go-heap.pprof")); err == nil {
		_ = pprof.WriteHeapProfile(f)
		_ = f.Close()
	}
	if f, err := os.Create(filepath.Join(*out, "go-goroutines.txt")); err == nil {
		_ = pprof.Lookup("goroutine").WriteTo(f, 1)
		_ = f.Close()
	}
	_ = logFile.Close()
	summary, _ := json.MarshalIndent(rep, "", "  ")
	_ = os.WriteFile(filepath.Join(*out, "summary.json"), summary, 0o600)
	fmt.Println(string(summary))
}

// runLoad sends requests through the SOCKS port for d, half small and half large, each on a new connection.
func runLoad(socks, smallURL, largeURL string, d time.Duration, workers int) (small, large phaseStats) {
	proxy, _ := url.Parse("socks5h://" + socks)
	client := &http.Client{
		Transport: &http.Transport{Proxy: http.ProxyURL(proxy), DisableKeepAlives: true},
		Timeout:   60 * time.Second,
	}
	var mu sync.Mutex
	var smallLat, largeLat []time.Duration
	deadline := time.Now().Add(d)
	var wg sync.WaitGroup
	for w := range workers {
		wg.Go(func() {
			for i := 0; time.Now().Before(deadline); i++ {
				isLarge := (i+w)%2 == 1
				target, st, lat := smallURL, &small, &smallLat
				if isLarge {
					target, st, lat = largeURL, &large, &largeLat
				}
				t := time.Now()
				n, err := fetch(client, target)
				took := time.Since(t)
				mu.Lock()
				st.Requests++
				st.Bytes += n
				st.Seconds += took.Seconds()
				if err != nil {
					st.Errors++
					if st.FirstErr == "" {
						st.FirstErr = err.Error()
					}
				} else {
					*lat = append(*lat, took)
				}
				mu.Unlock()
			}
		})
	}
	wg.Wait()
	finish(&small, smallLat)
	finish(&large, largeLat)
	return small, large
}

func fetch(client *http.Client, target string) (int64, error) {
	// The client's Timeout bounds the request.
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, target, nil)
	if err != nil {
		return 0, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	n, err := io.Copy(io.Discard, resp.Body)
	if err == nil && resp.StatusCode != http.StatusOK {
		err = fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return n, err
}

func finish(st *phaseStats, lat []time.Duration) {
	if st.Seconds > 0 {
		st.MbitPerS = float64(st.Bytes) * 8 / 1e6 / st.Seconds
	}
	if len(lat) == 0 {
		return
	}
	slices.Sort(lat)
	st.P50Millis = lat[len(lat)/2].Milliseconds()
	st.P90Millis = lat[len(lat)*9/10].Milliseconds()
	st.MaxMillis = lat[len(lat)-1].Milliseconds()
}

// watchHeap keeps the highest in-use heap seen, sampled every 500 ms, until the returned stop is called.
func watchHeap(peak *atomic.Uint64) (stop func()) {
	done := make(chan struct{})
	go func() {
		t := time.NewTicker(500 * time.Millisecond)
		defer t.Stop()
		for {
			var ms runtime.MemStats
			runtime.ReadMemStats(&ms)
			if ms.HeapInuse > peak.Load() {
				peak.Store(ms.HeapInuse)
			}
			select {
			case <-done:
				return
			case <-t.C:
			}
		}
	}()
	return func() { close(done) }
}

func mb(b uint64) float64 { return float64(b) / (1 << 20) }

func fail(err error) {
	fmt.Fprintln(os.Stderr, "torbench:", err)
	os.Exit(1)
}
