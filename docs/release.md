# Releasing the Android app

The pipeline is `.github/workflows/android.yml`. Only Android is built, and only one file is published: a single
APK that holds every ABI. There is no Windows, desktop or server download.

| What you push | What runs |
|---|---|
| a branch (`main`) or a pull request | lint only: `flutter analyze` |
| a tag `0.1.0`, `v0.1.0`, `0.2.0-rc1` | build the signed APK and publish a GitHub Release |

```
git tag 0.1.0
git push origin 0.1.0
```

While the app is beta, every release is published as a pre-release, whatever the tag looks like, and its notes start
with the text of `.github/release-notes.md` (beta, partly AI-written, no warranty). The release holds one file,
`wardkeep-0.1.0.apk` (arm64-v8a, armeabi-v7a and x86_64 in one APK), and `SHA256SUMS`.
The app's version name is the tag; Android's version code is derived from it (`0.1.0` → 100, `1.2.3` → 10203),
so a later tag always counts as an update.

## The signing key

Every update of an installed app must be signed with the same key. The key is made once:

```
bash scripts/android-keystore.sh        # keystore + random 32-character password → .env
bash scripts/android-github-secrets.sh  # uploads them as repository secrets (needs `gh` logged in)
```

* `.env` (repository root), `app/android/omnitun-release.jks` and `app/android/key.properties` are git-ignored.
  **Back up `.env` and the keystore** (a password manager). Without them nobody can publish an update that
  installs over the existing app, and the key cannot be recovered.
* The repository secrets are `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`
  (the alias is `omnitun`). A release without them fails; it is never signed with a debug key.
* An app signed with an earlier key (a local build from before this key) must be uninstalled before the first
  release can be installed.

## Local release build

`scripts/build-android-release.sh` (all steps, one APK) or, with the Tor client and the core already built,
`cd app && flutter build apk --release --build-name=0.1.0 --build-number=100`; it signs with
`app/android/key.properties`.

## Dependencies

`.github/workflows/dependencies.yml` runs on the 1st of every month (and on request, from the Actions tab). It lists the
Go modules, Dart packages and Rust crates that have newer versions and opens one issue, labelled `dependency-check`,
with the list; if an issue is already open it is updated, and when everything is current it is closed. It only
checks: nothing is updated for you. Run the same report locally with `python scripts/dependency-report.py` (it needs
`go`, `flutter` and `cargo-outdated`; set `GO`, `FLUTTER` or `CARGO` if they are not on `PATH`). GitHub Actions are not in
the list: Dependabot proposes those (`.github/dependabot.yml`).

## Build environment

* The workflow installs **NDK 29** (`29.0.14206865`). The runner's own NDK 27 cannot link the Cronet library the core
  uses for NaiveProxy. Change `ANDROID_NDK_HOME` there together with the NDK your local builds use.
* Flutter is pinned to 3.47.7 in the workflow; Go comes from `go.mod`.

## Security notes

* Third-party actions in the workflow are pinned to commit SHAs; Dependabot proposes updates.
* The release job is the only one with write access (`contents: write`) and with the secrets.
