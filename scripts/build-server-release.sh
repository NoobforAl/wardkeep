#!/usr/bin/env bash
# Builds wardkeep-server for Linux (amd64 and arm64) into dist/, static and stripped, with SHA256SUMS.
# Usage: scripts/build-server-release.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-dev}"
TAGS="with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_acme,badlinkname,tfogo_checklinkname0"
mkdir -p dist
for arch in amd64 arm64; do
  GOOS=linux GOARCH="$arch" CGO_ENABLED=0 go build -tags "$TAGS" -trimpath \
    -ldflags "-s -w -checklinkname=0 -X main.version=$VERSION" \
    -o "dist/wardkeep-server-linux-$arch" ./cmd/wardkeep-server
done
(cd dist && sha256sum wardkeep-server-linux-* > SHA256SUMS)
ls -lh dist
