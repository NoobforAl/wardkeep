#!/usr/bin/env bash
# Builds the Go core for Android (gomobile .aar) into app/android/app/libs/.
# Run from Git Bash on Windows: gomobile panics on PowerShell's hidden "=C:" env vars.
# Requires Android SDK + NDK and JDK 17. gomobile/gobind are module tools (go.mod `tool`).
# Usage: scripts/build-android-core.sh [targets]   (default: android/arm64,android/arm,android/amd64)
set -euo pipefail
cd "$(dirname "$0")/.."

TARGETS="${1:-android/arm64,android/arm,android/amd64}"
# WARDKEEP_BUILD_MODE=release (the release workflow) builds with release log levels (core/buildinfo).
LDFLAGS="-checklinkname=0 -s -w"
if [[ "${WARDKEEP_BUILD_MODE:-}" == "release" ]]; then
  LDFLAGS="$LDFLAGS -X github.com/NoobforAl/wardkeep/core/buildinfo.Mode=release"
fi
# NaiveProxy's cronet-go asks the linker for `-l:libcronet.a`. Go 1.27.4 and later refuse such a flag in #cgo LDFLAGS
# unless it is allowed ("invalid flag in #cgo LDFLAGS"), and CI builds with the newest Go 1.27 (the workflows ask for `1.27`),
# so exactly that flag is allowed here (cmd/go anchors the pattern).
export CGO_LDFLAGS_ALLOW="${CGO_LDFLAGS_ALLOW:--l:libcronet\.a}"
TAGS="${TAGS:-with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_naive_outbound,badlinkname,tfogo_checklinkname0}"

if [[ -z "${ANDROID_HOME:-}" ]]; then
  if [[ -n "${LOCALAPPDATA:-}" ]]; then ANDROID_HOME="$LOCALAPPDATA/Android/Sdk"; else ANDROID_HOME="$HOME/Android/Sdk"; fi
  export ANDROID_HOME
fi
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | sort -V | tail -1)"
  export ANDROID_NDK_HOME
fi
if [[ -z "${JAVA_HOME:-}" && -d "/c/Program Files/Java/jdk-17" ]]; then export JAVA_HOME="/c/Program Files/Java/jdk-17"; fi

# Use the gomobile/gobind versions pinned in go.mod.
BIN="$(mktemp -d)"
go build -o "$BIN/" github.com/sagernet/gomobile/cmd/gomobile github.com/sagernet/gomobile/cmd/gobind
export PATH="$BIN:$PATH"

mkdir -p app/android/app/libs
gomobile bind -target "$TARGETS" -androidapi 29 -javapkg dev.omnitun -libname wardkeep \
  -trimpath -ldflags "$LDFLAGS" -tags "$TAGS" \
  -o app/android/app/libs/wardkeep-core.aar ./core/mobile
rm -rf "$BIN"
ls -lh app/android/app/libs/wardkeep-core.aar
