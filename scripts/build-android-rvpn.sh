#!/usr/bin/env bash
# Builds the rVPN client (rvpn/) for Android and copies it into the app as
# jniLibs/<abi>/libwardkeep_rvpn.so; Android only lets an app execute files from
# its native library directory, and the core finds it there.
# Needs: rustup targets (aarch64/armv7/x86_64-linux-android), cargo-ndk, Android NDK.
# Run from Git Bash. Usage: scripts/build-android-rvpn.sh [abi...]  (default: arm64-v8a)
set -euo pipefail
cd "$(dirname "$0")/.."

ABIS=("$@")
[[ ${#ABIS[@]} -gt 0 ]] || ABIS=(arm64-v8a)
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  SDK="${ANDROID_HOME:-${LOCALAPPDATA:+$LOCALAPPDATA/Android/Sdk}}"
  SDK="${SDK:-$HOME/Android/Sdk}"
  ANDROID_NDK_HOME="$SDK/ndk/$(ls "$SDK/ndk" | sort -V | tail -1)"
  export ANDROID_NDK_HOME
fi

declare -A TRIPLE=([arm64-v8a]=aarch64-linux-android [armeabi-v7a]=armv7-linux-androideabi [x86_64]=x86_64-linux-android)
cd rvpn
for abi in "${ABIS[@]}"; do
  cargo ndk -t "$abi" -P 29 build --release --bin wardkeep-rvpn
  dest="../app/android/app/src/main/jniLibs/$abi"
  mkdir -p "$dest"
  cp "target/${TRIPLE[$abi]}/release/wardkeep-rvpn" "$dest/libwardkeep_rvpn.so"
  ls -lh "$dest/libwardkeep_rvpn.so"
done
