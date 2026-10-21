# Performance, memory and leaks

How the Go core and server, the Rust Tor client and the Flutter app were measured, what was found, and
how to measure again. Numbers are from one Windows 11 PC (11th-gen i5, 12 threads), 2026-10-21.

## Measuring

### Go (core and server)

- **Profiles of a running program.** `omnitun-server run --pprof 127.0.0.1:6060` and
  `omnitun-svc --pprof 127.0.0.1:6060` serve Go's runtime profiles on a loopback address (other
  addresses are refused; off by default). Block and mutex profiling come on with the flag.
  ```
  go tool pprof -top http://127.0.0.1:6060/debug/pprof/heap
  go tool pprof -top http://127.0.0.1:6060/debug/pprof/profile?seconds=30
  go tool pprof -top http://127.0.0.1:6060/debug/pprof/goroutine
  go tool pprof -top http://127.0.0.1:6060/debug/pprof/mutex
  ```
- **Leak tests** (goroutines and heap after many cycles; `core/leakcheck`):
  `core/control` (client churn, request bursts), `server/runtime` (reload), `core/engine` (start/stop,
  opt-in: `OMNITUN_LEAK=1`, about a minute; `OMNITUN_LEAK_CYCLES`, `OMNITUN_LEAK_SETTLE` tune it).
  `OMNITUN_LEAK=1` also enables `TestLatencyConcurrencyCost`.
- **Benchmarks:** `go test -run xxx -bench . -benchmem ./server/stats ./server/logs ./core/control`.
- **Race detector.** Windows has no gcc, so run it in Docker:
  ```
  docker run --rm -v "$PWD:/src:ro" -v "$(go env GOMODCACHE):/gomod:ro" -v gocache:/gocache \
    -e GOMODCACHE=/gomod -e GOCACHE=/gocache -e GOPROXY=off -e GOFLAGS=-mod=mod -w /src golang:1.27 \
    go test -race -tags "$TAGS" -ldflags "-checklinkname=0" ./server/logs/ ./server/stats/ ./core/control/ ...
  ```
  (`TAGS` as in the Makefile.)

### Rust (`tor/`)

- `cargo build --profile profiling` is the release build with speed instead of size and with symbols kept
  (for `cargo flamegraph --profile profiling`, which needs an elevated shell on Windows).
- `cargo build --profile profiling --features dhat-heap` adds a heap profiler: run the binary, close its
  stdin (or let the core do it), and it writes `dhat-heap.json` (open it at
  https://nnethercote.github.io/dh_view/dh_view.html) and prints peak and final heap.
- Memory, handles and threads of the running process: PowerShell `Get-Process omnitun-tor`.

### Flutter (`app/`)

- `flutter test` runs with leak tracking on (`test/flutter_test_config.dart`): a controller, notifier or
  route that a test creates and never disposes fails the test.
- `test/rebuild_cost_test.dart` counts the widgets built for each speed report while connected (and has a
  budget so it cannot grow unnoticed).
- Real frame times and memory in profile mode, from `app/`:
  ```
  flutter drive --profile -d windows --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
  ```
  writes `build/*.timeline_summary.json` (build and raster time per frame, missed frames) and
  `build/memory.json` (process memory, Dart heap after a collection, top classes). Debug mode is several times
  slower and says nothing about the app. DevTools (`dart devtools`, or the link `flutter run --profile` prints)
  has the CPU profiler and memory snapshots for anything these do not show.

## Results

### Go

| What | Result |
|---|---|
| Idle server, 12 protocols, 1 user (`run --pprof`, 20 s) | 8 MB heap in use, 40 MB working set, 0.05 % CPU, 22 threads, 318 handles |
| Control server: 300 client connects/disconnects, 4000 requests from 32 callers | no goroutines or heap left behind; a request round trip takes 71 µs (598 B, 15 allocs) |
| Server reload ×30 (all protocols) | goroutines 142 → 142, heap +10 KiB per reload |
| Engine start/stop ×20 (2 s between start and stop) | goroutines 15 → 15, heap +47 KiB per cycle |
| `stats.Tracker.Save` (every 10 s) | 0.7 ms with 10 users, 1.1 ms with 200, 4.9 ms and 0.9 MB with 2000 |
| `Tracker.SetLive` (every 2 s) | 0.8 µs / 20 µs / 228 µs for 10 / 200 / 2000 users |
| `logs.Tail(200)` (served for `/logs` and the TUI) | **was 56.6 ms and 27 MB per call; now 0.6 ms and 320 KB** (read from the end of the file) |
| "Test all" for 32 servers | 32 at once: peak heap 11 MiB, 7 s; 8 at once: 9 MiB, 18 s; 2 at once: 8 MiB, 32 s. Running them together costs almost no memory, so the app does not limit it. |

Race detector: clean in `core/pprofsrv`, `core/control` (the tests that do not start sing-box), `core/dnscrypt`,
`core/tor`, `server/logs`, `server/stats`, `server/store`.

**Found, not ours (sing-box v1.14.3):**

- Stopping the engine while its first probes (urltest, DNS queries) are still in flight leaves a goroutine and a
  socket per stop, about 230 KiB of heap each (100 cycles with no pause: +104 goroutines, +22 MiB). Its UDP DNS
  transport has no `Close`, so the connection that is open at that moment is never closed. With 2 s between start
  and stop it does not happen. A user who connects and disconnects within the first seconds, many times in one
  run of the app, collects them. Worth reporting upstream; `OMNITUN_LEAK_SETTLE=0` reproduces it.
- The race detector reports two races in sing-box's urltest group (`URLTest.References` reading fields that
  `performUpdateCheck` writes), seen in `TestCallRunsMethodsInProcess` and `TestNoLeaseKeepsTunnel`.
- `server/hostproto` once failed with `sync: WaitGroup is reused before previous Wait has returned` inside
  `ameshkov/dnscrypt` `Server.Shutdown` (1 run in 4); it passed 3 times in a row afterwards.

### Rust

- The Tor client could not finish bootstrapping from this network (stuck at 15 %, "Problem downloading directory
  object"), so **the steady-state soak (connection churn, long runs) was not run.** What was measured before that:
  25 MB working set, 15–18 threads, 196 handles while waiting; the heap profile of the first 130 s peaked at 8 MB
  (7 MB at the end; 76 MB allocated in total over 217 000 blocks).
- Changed: a client that connects to the SOCKS port and does not finish its request is dropped after 10 s
  (`socks::HANDSHAKE_TIMEOUT`), and at most 2048 connections are served at once (the port stops accepting until
  one ends). Three unit tests cover the timeout.
- Not changed, not verified: `emit()` is a blocking `println!` and `report_path` calls it while holding a mutex
  (`main.rs`). If the core stopped reading the process's stdout, a worker thread could block there. The core
  reads it continuously, and reproducing it needs a live bootstrap, so it was left as it is.

### Flutter (Windows, profile mode, mock engine)

| Scenario | Frame build (avg / worst) | Raster (avg / worst) | Missed frames |
|---|---|---|---|
| Disconnected, 5 s | 0.95 / 2.1 ms | 4.0 / 6.2 ms | 0 |
| Connected, 15 s (speed every second, flow along the route) | 2.9 / 4.1 ms | 4.2 / 4.9 ms | 0 |
| Turning the globe, 8 drags | 2.3 / 6.8 ms | 6.5 / 13.0 ms | 0 |

- The real app, idle on Windows: 277 MB working set, 0.05 s of CPU in 30 s (0.2 %), 740 handles, 31 threads.
- Memory over 20 disconnect/connect cycles: the Dart heap stays flat (74 MB after a collection, the same at the first
  and the last cycle; the classes holding it are strings and maps, which look like the test's own copy of the traced timeline); the process grows from
  665 MB to 693 MB over the last 16 cycles, so it levels off. No leak found. The 440–690 MB total is mostly the
  engine and graphics, not Dart.
- One speed report builds about 199 widgets on the phone layout and 330 on the wide one (3 ms per frame when
  connected). That is cheap, so the home screen was **not** restructured; `test/rebuild_cost_test.dart` keeps it
  from growing.

**Fixed (found with leak tracking and tests):**

- Wide layout: `_WideBody.build` made a new page route on every build, and builds happen every second while
  connected; only the first was ever used, the rest were never disposed (14 routes and 14 notifiers in a 10 s
  test). The route is now made when the navigator asks for it.
- The password dialog and the new-group dialog created their text controllers outside the dialog and never
  disposed them; each dialog now owns its controllers.
- "Test all": results that arrived after the user left the screen threw (`ref` used after its widget was gone) and
  were lost; none of 6 were recorded in the test, all are now (`test/latency_dispose_test.dart`).

## Not measured

- Sustained traffic through the server (throughput, CPU and allocations per connection under load). Idle and
  connectivity were measured; a load run needs `make docker-e2e` with `--pprof` on the server.
- The Android core and the app on a phone (no device was used: it is the user's own VPN).
- Tor under load, as above.
- The DNSCrypt UDP front keeps a 64 KiB buffer per client session, up to 4096 sessions
  (`server/hostproto/dnscrypt.go`), 256 MiB if every session were touched. The pages of a fresh buffer are not
  committed until used, so the real cost is probably far lower, but it was not measured.
