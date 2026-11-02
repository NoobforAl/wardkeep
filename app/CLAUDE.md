# app/: the Flutter client

The UI of Wardkeep: Android (first-class), Windows (proxy mode, optional service), Linux; iOS and macOS are scaffolded
only. One Mullvad-style screen (status, country, one button) plus managers for servers, subscriptions, DNS, bypass
lists, logs and settings. 13 languages. State is Riverpod (`flutter_riverpod` 3, `Notifier`/`NotifierProvider`),
navigation is `go_router`.

The UI has **no VPN logic of its own**. Everything that connects, imports, parses or tests goes to the Go core over the
control protocol. To understand what a call does, read [`../core/CLAUDE.md`](../core/CLAUDE.md) and `core/control`.

Commands and the "use `make`" rule are in the [root guide](../CLAUDE.md). The root `make` targets cover the app:
`make app-test` (analyze + test), `make fix` (`dart fix --apply` + analyze), `make lint` (analyze), `make dev-android`
(ask first: installs on the maintainer's phone). Single test file: `cd app && flutter test test/dns_test.dart`.
If `flutter` is not on PATH, `make fix`/`make lint` still find `~/flutter/bin`; `make app-test` does not.
Do not run `dart format` over the tree: the project leaves it out on purpose (it would rewrite every file).

## Layout (`lib/`)

| Dir | What |
|---|---|
| `main.dart` | Startup: splash image decode (`SplashCover.prepare()`), store, window setup, incoming files/links, `ProviderScope` |
| `engine/` | The contract with the core. `engine.dart` is the `VpnEngine` interface plus the data classes. `core_engine.dart` is what the app uses (starts the core and reconnects); `daemon_engine.dart` speaks the control protocol to `wardkeep-svc` (desktop); on Android the core runs in-process through the `wardkeep/core` MethodChannel; `mock_engine.dart` is the fallback and the test double; `log_record.dart` is the log record of `docs/logging.md` |
| `state/` | Providers and persistence (`providers.dart`, `store.dart`), plus countries, DNS, bypass, subscriptions, usage, IP database (`ipdb*.dart`), tray menu, window bounds, log alerts |
| `ui/screens/` | One file per screen (`home_screen.dart` is the biggest) |
| `ui/widgets/` | Shared widgets: `earth_globe.dart`, `splash.dart`, `window_frame.dart`, `notice.dart`, ... |
| `ui/` | Theme, layout breakpoints (`layout.dart`), motion, tray, system notifications, importing shared files |
| `l10n/` | `app_*.arb` (13 languages, `app_en.arb` is the template) and the **generated** `app_localizations*.dart`; `errors.dart` maps core error codes to translated text |

Native Android code is in `android/app/src/main/kotlin/dev/omnitun/` (`MainActivity`, `WardkeepVpnService`,
`CorePlatform`). The package/app id still says `omnitun` on purpose: do not rename it (it would break updates on
installed phones). Windows/Linux/macOS runner folders are Flutter's generated scaffolding plus the tray/window glue.

## Rules specific to the app

- **Thin client.** Do not port logic that belongs to the core into Dart (parsing links, building configs, deciding
  failover). Add a control method in `core/control` and call it from `engine/`. Both sides change together, with a test each.
- **Strings**: never hard-code user-facing text. Add the key to **every** `app/lib/l10n/app_*.arb` at once with
  `python scripts/add-l10n.py new_messages.json` (the format is in the script's docstring), then `cd app && flutter gen-l10n`.
  Never hand-edit `app_localizations*.dart`. Core errors arrive as a **code**; translate the code in `l10n/errors.dart`,
  not the English message. Eight of the 13 languages are machine-written; right-to-left languages (fa, ar, ur) must keep working,
  so use directional-aware widgets (`EdgeInsetsDirectional`, `AlignmentDirectional`).
- **Privacy decisions already made**: the QR scanner is Google-free (`flutter_zxing` + `camera`, no ML Kit/Play services);
  the IP lookup is on by default, the offline IP database is a manual download. Encrypting stored credentials with the OS
  keystore was decided but is not finished (check the code before assuming it is in place). Do not add analytics, crash reporters, or any network call that `PRIVACY.md` does not list; if you add one,
  update `PRIVACY.md` and the in-app privacy screen strings in the same change.
- **Logging**: show and store records in the `docs/logging.md` shape; the user-facing setting is *Debug logging* (auto-off after
  24 h). Never put a server address, key or profile name into a log or a notification.
- **Analyzer is strict** (`analysis_options.yaml`: strict casts/inference/raw types, leak rules such as `cancel_subscriptions`,
  `close_sinks`, unawaited futures). `flutter analyze` fails on *any* finding, infos included. Dispose controllers,
  cancel subscriptions, close sinks. Prefer fixing over `// ignore:`; an ignore needs a reason after it.
- **Widget tests detect leaks** (`test/flutter_test_config.dart` enables `leak_tracker`): a controller, notifier or animation
  a test creates and does not dispose fails that test.
- **Layout**: the same screens run on a 360 px phone and on a wide desktop window (`ui/layout.dart`, `wide_layout_test.dart`,
  `home_layout_test.dart`). Check both when you touch `home_screen.dart`. Respect a large system font scale.
- **Startup is timed.** The loading screen decodes the shield before `runApp` (capped at 500 ms); do not add awaits to `main()`
  without measuring a cold start (`docs/performance.md`).
- **Dependencies**: `pubspec.lock` is the truth (CI runs `flutter pub get --enforce-lockfile`). After changing `pubspec.yaml` run
  `make notices`. Exact-pin or caret choices follow the existing style. If pub.dev answers 403 on your network, see the root
  guide's note; never commit a lockfile that points to a mirror.

## Tests

- `test/*_test.dart` are widget and unit tests (about 50 files, 350+ cases). `integration_test/perf_test.dart` plus `test_driver/`
  measure frame times of the real app in profile mode (see `docs/performance.md`); they are not part of `make app-test`.
- Tests that drive the real Go daemon (`daemon_engine_test.dart`, the real-core part of `core_messages_test.dart`) are
  **skipped unless `bin/wardkeep-svc(.exe)` exists**. Run `make build` first when you change the engine contract, otherwise
  "all green" did not exercise the real core.
- A phone is the only way to verify VPN service, notifications, the QR camera and the loading screen on Android. A green
  `flutter test` does not prove any of those; say what you ran on a device and what you did not. The attached phone is the
  maintainer's **real VPN**: before touching it note which server is connected, delete any test profile you import,
  restore their connection afterwards, and reset any `wm size`/`wm density`/`font_scale` you changed in the same command.
- Android builds: the installed app is signed with the *old* release key, so a plain local build cannot replace it, and
  without `--split-per-abi` the version code goes backwards. Prefer asking the maintainer how to install over improvising;
  `scripts/build-android-core.sh` (Git Bash) rebuilds the Go core after core changes.
