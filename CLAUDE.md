# Wardkeep: guide for coding agents

Wardkeep is a cross-platform VPN client (Flutter app + Go/Rust core) and a server for running your own VPN.
Go module: `github.com/NoobforAl/wardkeep`. Android is the first-class client; Windows runs in proxy mode.
It is beta software, tested in code, in Docker and on one real phone, and nothing more.

## Read the guide of the part you work in

Each large part has its own `CLAUDE.md` with the architecture, the invariants and the local commands. Read it
before you change that part (Claude Code loads it by itself when you read a file there, but read it on purpose
when the task is more than a one-line fix).

| Part | Guide | What it is |
|---|---|---|
| `core/` | [`core/CLAUDE.md`](core/CLAUDE.md) | Go: profiles, importers, sing-box config, the engine, the control protocol, Android entry point, Windows service and kill switch. Read it to understand how a connection is made. |
| `tor/` | [`tor/CLAUDE.md`](tor/CLAUDE.md) | Rust: `wardkeep-tor`, Arti behind a local SOCKS5 port. Started and read by `core/tor`. |
| `app/` | [`app/CLAUDE.md`](app/CLAUDE.md) | Flutter UI (Android, Windows, Linux), 13 languages, Riverpod, talks to the core over the control protocol. |
| `server/`, `cmd/` | `docs/server.md` | VPN server (13 protocols, users, quotas, TUI, web API) and the three executables. No guide of its own yet. |

Cross-cutting docs: `docs/logging.md` (the one log format for all four processes, **read it before adding a log
line or an error path**), `docs/release.md` (CI and releases), `docs/performance.md`, `docs/app.md` (user-facing
behaviour), `CONTRIBUTING.md` (what is security-sensitive, how commit messages are written).

## Use `make`, not the underlying commands

Go here only builds and tests correctly with a long list of sing-box **build tags** and linker flags. A plain
`go test ./...` either fails to compile or, worse, silently skips the end-to-end tests (they are behind the tags
`with_quic && with_utls && with_wireguard && with_gvisor`) and reports green. The Makefile holds the tags in one
place (`TAGS`), so go through it.

| Task | Command | Notes |
|---|---|---|
| Go tests (core + server) | `make test` | the whole tree; CI runs the same tags |
| Go vet | `make vet` | |
| Rust tests (`tor/`) | `make tor` | `cargo test` in `tor/` |
| Flutter analyze + tests | `make app-test` | needs `flutter` on PATH (see below) |
| Build the executables | `make build` | `bin/wardkeep`, `bin/wardkeep-svc`, `bin/wardkeep-server`. The desktop app launches `bin/wardkeep-svc`; a few Flutter tests are skipped when it is missing |
| **Format and fix everything** | `make fix` | gofmt, `go fix`, `go vet`, `dart fix` + `flutter analyze`, `cargo fmt`. **Run it after every code change, before you report done.** It rewrites files; say which |
| **Lint everything** | `make lint` | golangci-lint (with gosec), govulncheck, clippy `-D warnings`, cargo-deny, `flutter analyze`. Run before committing code. Fix findings or add a narrow `nolint`/`allow` with a reason, never a blanket disable |
| Dependency licenses | `make notices` | run after changing any dependency in `go.mod`, `tor/Cargo.toml` or `app/pubspec.yaml` |
| Real VPN clients vs the Linux server | `make docker-e2e` | needs Docker, slow. Run it when you touch the server, a protocol or the tunnel. `PROTO="wireguard amneziawg"`, `E2E_ARGS="--only ipv6"` narrow it |
| Mesh (Tailscale/Headscale) in Docker | `make docker-mesh` | builds the core with `with_tailscale` |
| Run a dev server | `make dev-server` / `dev-tui` / `dev-web` | state in `.dev/` (`make dev-clean` deletes it) |
| Server release binaries | `make server-release` | `dist/` |
| List the dev targets | `make help` | |

Two targets act on real things; **ask before running them**: `make dev-android` (builds a release APK and installs
it on the connected phone, which is the maintainer's real VPN device) and `make clean` (deletes every build
cache, so the next build downloads and compiles everything again).

### One package or one test

`make` has no per-package target. For a focused run use the project's wrapper, which applies the same tags:

```powershell
./scripts/go.ps1 test ./core/engine -run TestName     # Windows (PowerShell); also build / vet / run
```

On Linux/macOS: `go test -tags "$(sed -n 's/^TAGS := //p' Makefile)" -ldflags=-checklinkname=0 ./core/engine -run TestName`.
Always finish with the real `make test`. Flutter and Rust are fine to run directly for one test:
`cd app && flutter test test/dns_test.dart`, `cd tor && cargo test socks`.

### Things that bite

- **Windows shells.** Recipes run in Git's `sh`, never WSL. A bare `bash` on PATH can be the WSL launcher: run the
  `scripts/*.sh` files from **Git Bash**, not PowerShell (`build-android-core.sh` fails silently otherwise).
  `scripts/go.ps1` splits `-flag=value.ext` at the dot: pass `-coverprofile coverage.out` as two words.
- **`flutter` not on PATH.** `make fix` and `make lint` fall back to `~/flutter/bin`, but `make app-test` and
  plain `flutter` calls do not. Put the SDK's `bin` on PATH for the call.
- **`WinDivert64.sys: no matching files`** when compiling anything that imports sing-box: antivirus removed a file
  from the module cache. Do not edit the cache; add the tag `with_external_windivert`:
  `make test TAGS="$(sed -n 's/^TAGS := //p' Makefile),with_external_windivert"` (same for `vet`).
- **pub.dev unreachable (HTTP 403) from some networks.** Do not let pub "upgrade to a mirror": it ignores the
  lockfile and moves dozens of packages. If you must use a mirror, keep `app/pubspec.lock` untouched
  (`git checkout app/pubspec.lock` afterwards).
- **Not covered by any command.** NaiveProxy tests (need cronet, see README *Develop*), Windows service and kill
  switch under real elevation, the Android VPN service and IPv6 on a real network are tested by hand or not at all.
  Say what you did not run; never call something verified from fakes alone.

## Rules that apply everywhere

- **Never weaken what the app promises**: traffic goes through the tunnel, DNS does not leak, secrets stay on the
  device or server. A change that can send a packet or a DNS query around the tunnel is a security change.
  `CONTRIBUTING.md` lists the load-bearing areas; the per-part guides repeat the ones that matter there.
- **Treat every import as hostile**: share links, subscriptions and config files come from strangers.
- **Secrets**: never commit or print a keystore, `.env`, `key.properties`, a password or a token. They are
  git-ignored (`app/android/*.jks`, `app/android/key.properties`, `app/android/old-key/`, `.env*`).
- **Logging**: one JSON record per line, keys and levels as in `docs/logging.md`. Never log destinations, server
  addresses, keys, passwords, tokens, subscription URLs or profile names.
- **Names kept on purpose**: the product is *Wardkeep* (repo `NoobforAl/wardkeep`), but names that already live on
  users' devices still say `omnitun`: the Android application id `dev.omnitun.app`, the Kotlin package `dev.omnitun`,
  `omnitun-release.jks`, data directories and unit names. Do not "finish the rename".
- **Generated or vendored, do not hand-edit**: `app/lib/l10n/app_localizations*.dart` (from the `.arb` files via
  `flutter gen-l10n`), `THIRD_PARTY_NOTICES.md`, `go.sum`/`Cargo.lock`/`pubspec.lock` except through the tool.
  `third_party/` holds patched copies of libraries; every change there also goes in that folder's `PATCHES.md`.
- **Commits**: subject starts with the area (`Core:`, `Server:`, `App:`, `Tor:`, `CI:`, `Installer:`) and says what
  changed, not how. The *why* (what was wrong, what was rejected) goes in the message body; `git log` is where
  this project keeps it. Comments explain constraints and failures, not the line below them.
- **Shared working tree**: the maintainer edits the same checkout while you work. Stage only the files you
  changed (`git add <paths>`, never `git add -A`), make small targeted edits to shared files, and do not
  `git checkout`/`stash` paths you did not touch. A local, uncommitted `PLAN.md` may exist; never commit it.
- **Don't commit or push** unless asked.

## Layout

```
app/        Flutter client                       cmd/        wardkeep (dev CLI), wardkeep-svc (core daemon), wardkeep-server
core/       Go core (see core/CLAUDE.md)         server/     VPN server packages (api, manager, runtime, tui, store, ...)
tor/        Rust Tor client (see tor/CLAUDE.md)  third_party/ patched dnstt, sing-openvpn, saturating-time
scripts/    build + generator scripts            tools/      devserver, dockertest (e2e), awgdev, torbench
installer/  Windows (Inno Setup) and Linux installers      docs/   guides listed above
```
