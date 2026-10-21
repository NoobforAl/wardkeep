# Releasing

The pipeline is `.github/workflows/release.yml`, with the checks of `.github/workflows/ci.yml`. A release holds
three files and their checksums:

| File | What |
|---|---|
| `wardkeep-<version>.apk` | Android 10+, arm64-v8a, armeabi-v7a and x86_64 in one signed APK |
| `wardkeep-<version>-windows-x64-setup.exe` | Windows installer, per user (Inno Setup, `installer/wardkeep.iss`) |
| `wardkeep-<version>-linux-x64-setup.sh` | Linux installer, per user (`installer/linux`), run with `sh` |
| `SHA256SUMS` | checksums of the three |

There is no portable (unzip-and-run) build and no system-wide package; no server binary is published.

| What you do | What runs |
|---|---|
| push to `main`, open a pull request | `ci.yml`: the checks (Go, Rust, Flutter tests and lint, license check) |
| push a tag `0.1.0`, `v0.1.0`, `0.2.0-rc1` | `release.yml`: the same checks, then the builds, then the GitHub Release |
| Actions → Release → **Run workflow** (any branch) | the same, but nothing is published: the files stay as run artifacts (named `dev-<commit>`) |

```
git tag 0.1.0
git push origin 0.1.0
```

While the app is beta, every release is published as a pre-release, whatever the tag looks like, and its notes start
with the text of `.github/release-notes.md` (beta, partly AI-written, no warranty). The app's version name is the tag;
Android's version code (and Windows' build number) is derived from it (`0.1.0` → 100, `1.2.3` → 10203), so a later tag
always counts as an update.

## How the pipeline is ordered

```
checks ─┐
prepare ┴─▶ android-tor + android-core ─▶ android ──────────────────────┐
            core-windows + app-windows ─▶ package-windows ──────────────┼─▶ publish
            core-linux   + app-linux   ─▶ package-linux   ──────────────┘
```

* **Nothing is built if the checks fail.** Every build job needs `checks` (the tests and lint of `ci.yml`, called as a
  reusable workflow) and `prepare` (the version and, for a tag, the Android signing secrets: a missing secret stops the
  run in a minute, not after the build).
* **Nothing is published if any build fails.** `publish` needs the Android APK and both installers, and the installers
  have been installed, checked and uninstalled on the runner before they get that far. A failed run leaves no
  half-made release.
* **Independent work runs side by side:** the Tor client (Rust) and the Go core of the Android app, the Go core and
  the Flutter app of each desktop system, and the three systems themselves.
* **Caches:** Go modules and build cache (`setup-go`), Flutter SDK and pub cache (`flutter-action`), Cargo
  (`rust-cache`), Gradle (`setup-java`). A new push to a pull request cancels the older run of that pull request; a
  release run is never cancelled half-way. Intermediate files between jobs are kept for one day only.
* `flutter pub get --enforce-lockfile` everywhere: a `pubspec.yaml` that disagrees with `pubspec.lock` fails the run.

## The Windows installer

`installer/build-installer.ps1` builds it with Inno Setup 6; `installer/test-installer.ps1` is what the pipeline runs
to try it (silent install into a folder, files and registry entries, silent uninstall, nothing left, user data kept
unless asked for). Everything is per user: `%LOCALAPPDATA%\Programs\Wardkeep` and `HKEY_CURRENT_USER`. The app is
described in [app.md](app.md).

Signing is optional: with the repository secrets `WINDOWS_CERT_PFX_BASE64` (the `.pfx` file, base64) and
`WINDOWS_CERT_PASSWORD`, `omnitun.exe`, `omnitun-svc.exe`, the setup file and its uninstaller are signed
(`installer/sign.ps1`); without them the files are unsigned and Windows SmartScreen warns on the first start. The
certificate is only in the `package-windows` job, which runs nothing from dependencies.

## The Linux installer

`installer/linux/build-installer.sh <version> <bundle> <out>` packs Flutter's Linux bundle and `omnitun-svc` into one
self-extracting `sh` script (`setup-header.sh` plus a `tar.xz`, with the payload's SHA-256 inside so that a damaged
download is refused). It installs for the current user only and refuses to run as root: the program in
`~/.local/share/wardkeep`, the command `wardkeep` in `~/.local/bin`, a menu entry and icon, and (unless `--no-links`)
Wardkeep as the program for share links. `<prefix>/uninstall.sh` removes it again, keeping the user's data unless
`--purge` is given. `installer/linux/test-installer.sh` does all of that in a throw-away home folder and is what the
pipeline runs; it can also be run by hand on any Linux machine or in Docker:

```
installer/linux/build-installer.sh dev app/build/linux/x64/release/bundle dist   # omnitun-svc must be in the bundle
installer/linux/test-installer.sh dist/wardkeep-dev-linux-x64-setup.sh
```

The app is built on Ubuntu 22.04 so that it runs on that and newer systems (it links to the glibc and GTK of the
machine that builds it). When GitHub retires that image, move `core-linux`, `app-linux` and `package-linux` to the
oldest one left.

## The Android signing key

Every update of an installed app must be signed with the same key. The key is made once:

```
bash scripts/android-keystore.sh        # keystore + random 32-character password → .env
bash scripts/android-github-secrets.sh  # uploads them as repository secrets (needs `gh` logged in)
```

* `.env` (repository root), `app/android/omnitun-release.jks` and `app/android/key.properties` are git-ignored.
  **Back up `.env` and the keystore** (a password manager). Without them nobody can publish an update that
  installs over the existing app, and the key cannot be recovered.
* The repository secrets are `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`
  (the alias is `omnitun`). A tag without them fails; a release is never signed with a debug key. A manual run
  (no tag) is signed with the debug key and is only for trying.
* An app signed with an earlier key (a local build from before this key) must be uninstalled before the first
  release can be installed.

## Local builds

* Android: `scripts/build-android-release.sh` (all steps, one APK) or, with the Tor client and the core already built,
  `cd app && flutter build apk --release --build-name=0.1.0 --build-number=100`; it signs with
  `app/android/key.properties`.
* Windows: build `omnitun-svc.exe` (`./scripts/go.ps1 build -o dist/app/omnitun-svc.exe ./cmd/omnitun-svc`),
  `flutter build windows --release`, copy the Release folder into `dist/app`, then `installer/build-installer.ps1`.
* Linux: `flutter build linux --release` (needs `clang cmake ninja-build pkg-config libgtk-3-dev
  libayatana-appindicator3-dev`), a static `omnitun-svc` (`CGO_ENABLED=0 go build -tags <TAGS> -o <bundle>/omnitun-svc
  ./cmd/omnitun-svc`, the tags are in the `Makefile`), then `installer/linux/build-installer.sh`.

## Dependencies

`.github/workflows/dependencies.yml` runs on the 1st of every month (and on request, from the Actions tab). It lists the
Go modules, Dart packages and Rust crates that have newer versions and opens one issue, labelled `dependency-check`,
with the list; if an issue is already open it is updated, and when everything is current it is closed. It only
checks: nothing is updated for you. Run the same report locally with `python scripts/dependency-report.py` (it needs
`go`, `flutter` and `cargo-outdated`; set `GO`, `FLUTTER` or `CARGO` if they are not on `PATH`). GitHub Actions are not in
the list: Dependabot proposes those (`.github/dependabot.yml`).

## Build environment

* The Android jobs install **NDK 29** (`NDK_VERSION` in `release.yml`). The runner's own NDK 27 cannot link the Cronet
  library the core uses for NaiveProxy. Change it together with the NDK your local builds use.
* Flutter is pinned to 3.47.7 (`FLUTTER_VERSION` in `ci.yml` and `release.yml`: change both); Go comes from `go.mod`.

## Security notes

* Third-party actions in the workflows are pinned to commit SHAs; Dependabot proposes updates.
* The build jobs only read the repository. The ones that run code from dependencies (flutter pub, gradle, cargo,
  go build) hold no token that can write. The Windows certificate is only in `package-windows`. `publish` is the only
  job with write access (`contents: write`); it runs nothing but the GitHub CLI on the finished files. The Android
  signing key is in the `android` job, which builds the APK.

## Issue templates

`.github/ISSUE_TEMPLATE` has forms for a bug report, a connection problem and a feature request, and a link to
report a vulnerability or a leak privately. Both bug forms ask for logs with the passwords, keys and server addresses
removed.
