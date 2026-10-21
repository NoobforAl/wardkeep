#!/usr/bin/env bash
# Builds the per-user Linux installer: setup-header.sh (the installer) with the program (a tar.xz) behind it,
# in one file that is run with sh.
#
#   installer/linux/build-installer.sh <version> <bundle-dir> <out-dir>
#
# <bundle-dir> is Flutter's release bundle (build/linux/x64/release/bundle) with omnitun-svc, the core, next to
# omnitun. <version> is the name used in the file name (0.1.0, 0.2.0-rc1, dev-abc1234). Writes
# <out-dir>/wardkeep-<version>-linux-x64-setup.sh.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
ver="${1:?usage: build-installer.sh <version> <bundle-dir> <out-dir>}"
bundle="${2:?usage: build-installer.sh <version> <bundle-dir> <out-dir>}"
out="${3:?usage: build-installer.sh <version> <bundle-dir> <out-dir>}"

[[ "$ver" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]] || { echo "bad version: $ver" >&2; exit 1; }
for f in omnitun omnitun-svc lib/libflutter_linux_gtk.so data/icudtl.dat; do
  [[ -e "$bundle/$f" ]] || { echo "$bundle/$f is missing: is this Flutter's bundle with omnitun-svc in it?" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/stage/app" "$out"
cp -a "$bundle/." "$work/stage/app/"
cp "$root/LICENSE" "$work/stage/app/LICENSE.txt"
cp "$here/wardkeep.png" "$work/stage/wardkeep.png"
cp "$root/app/linux/packaging/omnitun.desktop" "$work/stage/dev.omnitun.app.desktop"

tar --owner=0 --group=0 --numeric-owner -C "$work/stage" -cf - . | xz -T0 -9 >"$work/payload.tar.xz"
sha="$(sha256sum "$work/payload.tar.xz" | cut -d ' ' -f 1)"

setup="$out/wardkeep-$ver-linux-x64-setup.sh"
sed -e "s|@VERSION@|$ver|" -e "s|@PAYLOAD_SHA256@|$sha|" "$here/setup-header.sh" >"$setup"
cat "$work/payload.tar.xz" >>"$setup"
chmod 755 "$setup"
echo "built $setup ($(du -h "$setup" | cut -f 1))"
