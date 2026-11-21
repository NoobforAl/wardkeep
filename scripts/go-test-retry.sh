#!/usr/bin/env bash
# Runs the Go tests; packages that fail are run once more on their own. A package that passes the second time is
# reported as flaky (named, never hidden), one that fails again fails the run. For `make deploy`: on this Windows
# machine a few tests fail now and then for reasons outside the code (antivirus holding a temporary directory:
# "TempDir RemoveAll cleanup"; a Reality handshake to a real website over a filtered network), and a whole new
# run of every package to tell them apart costs minutes.
#
# Usage: scripts/go-test-retry.sh <go test flags...> -- <packages...>
set -uo pipefail

flags=()
while [[ $# -gt 0 && $1 != "--" ]]; do flags+=("$1"); shift; done
shift || true
pkgs=("$@")
[[ ${#pkgs[@]} -gt 0 ]] || pkgs=(./...)

log=$(mktemp)
trap 'rm -f "$log"' EXIT

go test "${flags[@]}" "${pkgs[@]}" 2>&1 | tee "$log"
[[ ${PIPESTATUS[0]} -eq 0 ]] && exit 0

# "FAIL<tab>package<tab>time" is go test's summary line of a failed package; a build failure has no time.
mapfile -t failed < <(sed -n 's/^FAIL[[:space:]]\+\([^[:space:]]\+\).*/\1/p' "$log" | sort -u)
if [[ ${#failed[@]} -eq 0 ]]; then
  echo "go test failed, and no failed package was named (a build error?): not retried" >&2
  exit 1
fi

echo
echo "== Retrying once, on their own: ${failed[*]}"
if go test -count=1 "${flags[@]}" "${failed[@]}"; then
  echo
  echo "FLAKY (failed, then passed when run again): ${failed[*]}"
  echo "If one of these is yours, look at it; the known ones are listed in core/CLAUDE.md (Tests)."
  exit 0
fi
echo "Failed twice: a real failure." >&2
exit 1
