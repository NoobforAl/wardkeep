# tor/: `wardkeep-tor`, the Rust Tor client

A small Rust crate (edition 2024, about 1,500 lines) that runs **Arti** (the Rust Tor implementation) behind a
minimal local SOCKS5 server. It is a separate process, not a library the Go code links: `core/tor` starts the
binary, reads its stdout, and routes Tor profiles into its SOCKS port. Read [`../core/CLAUDE.md`](../core/CLAUDE.md)
for the Go side.

Commands and the "use `make`" rule are in the [root guide](../CLAUDE.md).

| Task | Command |
|---|---|
| Tests | `make tor` (= `cargo test` in `tor/`) |
| Lint | `make lint` runs `cargo clippy --all-targets -- -D warnings` and `cargo deny check` here, plus the other languages. Warnings fail the build |
| Format | `make fix` (`cargo fmt`; also formats Go and Dart) |
| Android binary | `scripts/build-android-tor.sh [abi...]` from **Git Bash** (needs cargo-ndk and the NDK); output `app/android/app/src/main/jniLibs/<abi>/libwardkeep_tor.so` |

Debug builds are optimized (`[profile.dev.package."*"] opt-level = 2`) because Arti's crypto is far too slow
unoptimized to verify a consensus; the first build is long, later ones are cached. The unit tests cover parsing,
SOCKS framing, path roles and log formatting, not a live Tor network.

## Files

| File | Role |
|---|---|
| `src/main.rs` | The binary: parses args, builds the Arti client (bridges, unmanaged pluggable transports), bootstraps, serves SOCKS, emits events. The only file with no unit tests (it is the Arti wiring) |
| `src/args.rs` | Command line: `--data DIR [--socks-port N] [--bridge LINE]... [--transport NAME=HOST:PORT]... [--log-level L]` |
| `src/socks.rs` | SOCKS5 server: no auth, CONNECT only, which is all the Go core needs |
| `src/path.rs` | The circuit a stream rides, as roles + country codes (guard/bridge, middle, exit) for the app's globe |
| `src/logging.rs` | `tracing` layer that writes log records as JSON on stdout (the format of `docs/logging.md`); every stdout line goes through `write_line`, which holds the lock so records never interleave |
| `src/lib.rs` | Exposes the modules to the binary and the tests |

## The contract with the Go core (change both sides together)

- **stdout** carries one JSON object per line: `listening {socks}`, `bootstrap {percent,status}`, `ready`,
  `path {hops:[{role,country}]}`, `error {message}`, and `log` records (the record's keys flattened next to `event`).
  The header of `src/main.rs` is the reference; the reader is `core/tor/process.go`; the format is `docs/logging.md`.
- **stderr carries nothing on purpose.** The core logs any stderr line as an error, so a stray `eprintln!` shows
  up in users' logs as a failure.
- **stdin is the lifeline.** The process exits when stdin closes, so it never outlives the core. Do not read stdin for
  anything else.
- **Bridges** use pluggable transports that the Go core runs in-process (obfs4, WebTunnel, Snowflake) and passes in as
  *unmanaged* transports (`--transport obfs4=127.0.0.1:PORT`). This crate never spawns a transport itself.
- The core finds the binary through `$WARDKEEP_TOR_BIN`, then next to the running executable
  (`core/tor` `FindBinary`); on Android it is `libwardkeep_tor.so` in the native library directory.
- If you add or rename an event or a flag: update the header comment in `main.rs`, `core/tor/process.go`,
  `docs/logging.md` and the tests on both sides.

## Rules

- **Privacy.** Only roles and country codes leave the process (`path.rs`): no relay addresses or fingerprints.
  Never log destinations a user connects to (host, IP, port), bridge lines, or keys, at any level, including `trace`
  (see `docs/logging.md`, *Never in a log*).
- **Lints are strict on purpose** (`[lints]` in `Cargo.toml`, and `clippy.toml` relaxes them only inside tests):
  `unsafe_code = forbid`, and `unwrap`, `expect`, `panic`, `todo`, `dbg!`, lossy `as` casts and more are warnings,
  which `-D warnings` turns into errors. A panic ends every connection. Handle the error, or use a narrow
  `#[allow(clippy::x)]` with a reason; do not weaken the `[lints]` table.
- **Release profile** is size-optimized with `panic = "abort"`, LTO and strip. For performance work use
  `cargo build --profile profiling` (symbols kept) or `--features dhat-heap` (heap profile); numbers are in
  `docs/performance.md`. `tools/torbench` is the Go-side benchmark.
- **TLS**: rustls with the `ring` provider, no OpenSSL, so it cross-compiles to Android. Arti needs a process-wide
  crypto provider installed at start. Do not add `native-tls` or `openssl`.
- **Dependencies**: Arti crates are all on the same version (`0.47`); upgrade them together. `cargo deny check`
  (`deny.toml`) fails on a new vulnerability, an unlisted license or a non-crates.io source; a new license or an
  advisory ignore needs a written reason. `cargo audit` is not used on purpose (explained in `deny.toml`).
- **`[patch.crates-io] saturating-time`** points to `../third_party/saturating-time`: the upstream crate loops forever on
  Windows while parsing a consensus. Keep the patch until upstream is fixed and record changes in its `PATCHES.md`.
- **Tests** live in `mod tests` at the bottom of `args.rs`, `logging.rs`, `path.rs`, `socks.rs`. CI runs them with
  `cargo llvm-cov` and sends coverage to Codecov (flag `rust`). Real Tor network behaviour (bootstrap, bridges, circuits)
  is not tested in CI; say so when you change `main.rs`.
