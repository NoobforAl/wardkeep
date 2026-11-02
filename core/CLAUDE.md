# core/: the Go core

Everything that turns "a profile" into "a running tunnel", plus the protocol the UI uses to drive it. It is
shared by three executables (`cmd/wardkeep-svc` the desktop daemon, `cmd/wardkeep` the dev CLI, and the Android
app through `core/mobile`) and, for the protocol registry, links and importer, by `server/`.

Commands and the "use `make`" rule are in the [root guide](../CLAUDE.md). Short version: `make test`, `make vet`,
`make fix`, `make lint`; one package with `./scripts/go.ps1 test ./core/<pkg> -run X`. Never plain `go test`.

## How a connection is made

```
share link / file / subscription
  -> importer (parse)  ->  profile.Profile  (protocol-neutral model)
  -> singbox.Build     ->  sing-box JSON config (proxy or TUN mode, selector + urltest groups, DNS, bypass)
  -> engine            ->  runs sing-box in-process; failover, latency tests, stats, kill switch hooks
  -> control           <-  the UI (loopback TCP, JSON lines, token) starts/stops/selects and gets state + logs
```

and the other way for sharing: `protocols` (the registry) -> `links.Export` -> a share link / QR.
`importer.ParseLink(links.Export(p))` must give `p` back; keep that round trip true.

## Packages

**Model and parsing**
- `profile`: the protocol-neutral `Profile`, the editor forms (`form.go`, 16 protocols), warnings, Tor/DNS-tunnel options.
- `importer`: links (`links*.go`), base64 subscriptions, Clash / sing-box / Xray JSON, WireGuard `.conf`, OpenVPN `.ovpn`,
  Tailscale, Tor bridges. Input is hostile; every parser has a test for the odd case.
- `links`: profile -> share link (reverse of `importer`).
- `subscription`: download and parse provider subscriptions (usage/expiry headers, signed subscriptions in `signature.go`).
- `protocols`: **the one place that knows each protocol** (Spec, server `Inbounds`, client `Profile`). The server and the
  client both read it, so a protocol is added here first.
- `nordlynx`: NordVPN token -> WireGuard profiles.

**Building and running**
- `singbox`: profiles -> sing-box config. Bypass lists/countries (`bypass*.go`), Tailscale (`tailscale_on.go` /
  `tailscale_off.go`, tag `with_tailscale`), TUN names.
- `engine`: runs the tunnel (`engine.go`), failover, handshake steps and progress, bypass, and the side engines: `awg.go`
  (AmneziaWG), `dnscrypt.go`, `dnstt.go`, `tor.go`, `mesh.go`. `errors.go` maps raw errors to stable codes and
  user-fit messages (the scrubbing itself is `logrec.Scrub`). The biggest package (45 files) and the one where a mistake leaks.
- `control`: the UI <-> core protocol (`protocol.go`, `server.go` dispatch, `client.go`). The first request must be
  `hello` with the token; the tunnel stops when no UI is connected.
- `netcheck`: "is there internet at all?", so the UI says *no internet* instead of failing over.
- `awg`, `dnscrypt`, `dnstt`, `tor`: the runners for AmneziaWG (TUN fd from the OS), DNSCrypt (+ loopback forwarder), the DNS
  tunnel client (over `third_party/dnstt`), and Tor (`core/tor` starts the Rust `wardkeep-tor` binary, see [`../tor/CLAUDE.md`](../tor/CLAUDE.md);
  bridges' pluggable transports obfs4/WebTunnel/Snowflake run in-process in Go).

**Platforms**
- `mobile`: the gomobile entry point for Android. Runs the same control server inside the app process and plugs
  `VpnService` into sing-box (`Platform`). Built by `scripts/build-android-core.sh` into `app/android/app/libs/wardkeep-core.aar`.
- `winsvc`, `killswitch`: Windows service (LocalSystem) and WFP kill switch. They run elevated and have **never been
  exercised with real elevation**. Read twice, say what you could not run.

**Support**: `logrec` (the log record, level gate, notify de-duplication, panic report; implements `docs/logging.md`),
`buildinfo` (`Mode` = dev/release via ldflags), `pprofsrv` (loopback-only pprof, behind `--pprof`), `leakcheck` (test-only
goroutine/heap leak checks).

## Rules specific to the core

- **Leak safety is the product.** In `singbox`, `engine` and `killswitch`, ask of every change: can a DNS query, an IPv6
  packet, a bypass-listed address or a reconnect gap leave outside the tunnel? If yes it is a security change; write the
  reasoning in the commit message and add a test (`engine/leak_test.go`, `mtu_ipv6_test.go`, `e2e_bypass*_test.go` show how).
- **`control` is a security boundary** (loopback + token). Do not add a method that can read files, run commands or
  expose secrets without the same scrutiny. Any new method or field must be mirrored in the Dart client,
  `app/lib/engine/daemon_engine.dart` (and `core_engine.dart` for the Android channel), and have a test on each side.
- **Errors**: use the typed codes in `engine/errors.go` (`ErrTimeout`, `ErrAuth`, ...); the app translates the *code*,
  never the message. Pass library errors through `logrec.Scrub` (hosts, IPs) before logging or returning them.
- **Logging**: through `logrec`, level checked before formatting, `notify:true` only for errors nothing handled, never
  destinations/keys/profile names (`docs/logging.md` section 1).
- **Platform and tag files**: split by filename suffix (`_windows.go`, `_linux.go`) or build tag (`_other`, `_on`/`_off`).
  `go vet` on Windows does not compile the Linux-only files and the reverse; CI's `go-lint` job runs on Linux for that.
  When you add a Windows-only function, add the `other` stub.
- **Adding a protocol**: start in `protocols` (Spec, Inbounds, Profile), then `profile/form.go` (editor), `importer`
  (parse), `links` (export), `singbox.Build` (config); add a round-trip test, an engine e2e test if sing-box can run it
  in-process, and the Docker e2e (`tools/dockertest`) if it needs a real client. The app needs its label/strings in all
  13 `.arb` files (see [`../app/CLAUDE.md`](../app/CLAUDE.md)).
- **Dependencies**: sing-box is pinned (see `go.mod`); `-checklinkname=0` and the `badlinkname`/`tfogo_checklinkname0`
  tags are required for it. Upgrading it is its own change. After touching `go.mod`, run `make notices`.

## Tests

- Unit tests sit beside the code. The engine e2e tests (`core/engine/e2e_*_test.go`, `run_test.go`, `leak_test.go`, ...)
  carry `//go:build with_quic && with_utls && with_wireguard && with_gvisor`; without the tags they **do not exist**.
  That is the whole reason for `make`.
- Extra tags exist on purpose: `with_naive_outbound` (needs cronet, README *Develop*), `with_tailscale` (`make docker-mesh`).
  `live_test.go` and some e2e files need real network or a real server; look at the top of the file before running.
- Tests that start and stop things repeatedly use `core/leakcheck` to assert no goroutine or heap growth.
- Fixtures: `core/engine/testdata`. `cache.db` files that tests create are git-ignored; do not commit them.
- Windows only: `TempDir RemoveAll cleanup: directory is not empty` appears occasionally (antivirus); rerun before
  concluding anything.
