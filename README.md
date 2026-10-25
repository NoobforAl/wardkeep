# Wardkeep

Cross-platform VPN client (Flutter) with a Go/Rust core, plus a server for running your own VPN with many protocols.
Android is the first-class client; the Windows app runs in proxy mode. The app is a Mullvad-style single screen
(status, country, one button), translated into 13 languages (English, Persian, Russian, Chinese, Arabic, Spanish, Hindi, French, Portuguese, Urdu, Indonesian, Turkish, Vietnamese).

> **This is beta software.** It works on the devices it was tried on, but it has bugs and rough edges, and
> things may change between releases.
>
> **Part of the code was written with AI assistance.** It is tested, but it has not been independently audited,
> so do not rely on it where your safety depends on it.
>
> **No warranty.** It is provided "as is" under the [MIT license](LICENSE); the authors are not liable for any
> damage, data loss or consequence of using it.

* [App guide](docs/app.md) · [Server guide](docs/server.md) · [Contributing](CONTRIBUTING.md) · [Releasing](docs/release.md)
* The release notes on GitHub say what was tried on real devices and what was only tested in code.

## Download

Every release (GitHub, Releases) has three files, each with its checksum in `SHA256SUMS`:

| File | For |
|---|---|
| `wardkeep-<version>.apk` | Android 10 or newer; one signed APK for every phone |
| `wardkeep-<version>-windows-x64-setup.exe` | Windows 10 or 11, 64-bit; installs for the current user (no administrator rights) |
| `wardkeep-<version>-linux-x64-setup.sh` | Linux, 64-bit, glibc 2.35 or newer (Ubuntu 22.04, Debian 12, Fedora 36, ...) with GTK 3; installs for the current user (no root), run it with `sh` |

There is no portable build and no system-wide package: the two desktop files are installers that put everything in
your own folders and come with an uninstaller (see [the app guide](docs/app.md)). The Linux app has been built and its
installer tested by CI, but not yet tried by hand on a real desktop.

## Layout

| Path | What |
|---|---|
| `app/` | Flutter client (Android, Windows, Linux; iOS/macOS scaffolded) |
| `core/profile` | Protocol-neutral profile model |
| `core/importer` | Share links, base64 subscriptions, Clash / sing-box / Xray JSON, WireGuard/AmneziaWG `.conf`, OpenVPN `.ovpn`, Tor bridges |
| `core/links`, `core/profile` | Profiles back into share links; the profile editor's forms (18 protocols, the DNS tunnel among them); signed subscriptions |
| `core/protocols` | The protocol registry shared by the server and the client |
| `core/singbox` | Profiles → sing-box config (proxy or TUN mode, selector + urltest groups) |
| `core/engine` | Runs sing-box in-process: start/stop, live profile switching, traffic stats, latency tests |
| `core/control` | UI ↔ core protocol (loopback TCP, JSON lines, token auth); tunnel stops when no UI is connected |
| `core/netcheck` | "Is there internet at all?" check, so we report *no internet* instead of failing over |
| `core/mobile` | gomobile entry point for Android: runs the control server in-process and plugs `VpnService` into sing-box |
| `cmd/omnitun-svc` | Core daemon the desktop app launches (exits when the app dies) |
| `cmd/omnitun` | Developer CLI for the core |
| `cmd/omnitun-server` + `server/` | VPN server: 15 protocols (VLESS+Reality, Shadowsocks 2022, Trojan, Hysteria2, TUIC, AnyTLS, ShadowTLS, NaiveProxy, WireGuard, OpenVPN, a DNS tunnel, and SSTP, IKEv2, AmneziaWG on Linux), users, quotas and traffic accounting, one subscription link per user, ACME certificates, `init` wizard, `install` for systemd and firewall, cobra CLI (`omnitun-server --help`, `--json`), Bubble Tea TUI (`tui`), web API with OpenAPI docs (`api enable`, then `run`; docs at `/docs`) |
| `server/hostproto` | SSTP, IKEv2 and AmneziaWG servers and their NAT (Linux, `CAP_NET_ADMIN`) |
| `third_party/veepin` | Patched copy of the pure-Go SSTP/IKEv2 library (see `PATCHES.md`) |
| `tools/devserver` | Local Shadowsocks server for manual tests (e.g. phone over `adb reverse tcp:8388 tcp:8388`) |
| `tor/` | Rust Tor module (Arti) with a C ABI |

## Develop

```sh
# Go core — always build with the sing-box feature tags:
#   Windows: ./scripts/go.ps1 <cmd> ...     Linux/macOS: make test / make build
./scripts/go.ps1 test ./...
./scripts/go.ps1 run ./cmd/omnitun import links.txt
./scripts/go.ps1 run ./cmd/omnitun config links.txt
./scripts/go.ps1 run ./cmd/omnitun run links.txt   # SOCKS5/HTTP proxy on 127.0.0.1:2080

# Android core (.aar) — from Git Bash; needs Android SDK/NDK + JDK 17
scripts/build-android-core.sh            # all ABIs; or: scripts/build-android-core.sh android/arm64
# One signed release APK with every ABI in it; creates a keystore on first run —
# back up app/android/omnitun-release.jks and key.properties
scripts/build-android-release.sh         # add --skip-core to reuse the existing .aar

# NaiveProxy tests need Chromium's cronet (Android builds include it; on Windows
# cronet loads libcronet.dll from the Go module cache, found by the tests)
go test -tags=with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_purego,badlinkname,tfogo_checklinkname0   -ldflags=-checklinkname=0 -run 'Naive|Generated' ./core/engine/ ./server/runtime/

# Rust
cd tor && cargo test

# Flutter
cd app && flutter test && flutter run -d windows
```

On desktop the app launches `bin/omnitun-svc(.exe)` (or `OMNITUN_SVC`, or the copy next to the app executable), so build it first:
`./scripts/go.ps1 build -o bin/ ./cmd/...`. Without it — the app falls back to a preview engine and says so in Logs.

## License

MIT
