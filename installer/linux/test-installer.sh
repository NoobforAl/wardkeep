#!/usr/bin/env bash
# Tries the Linux installer in a throw-away home folder: installs, updates, refuses what it must refuse,
# uninstalls (keeping, then deleting, the user's data) and checks that nothing of it is left. Nothing outside the
# temporary folder is touched.
#
#   installer/linux/test-installer.sh dist/wardkeep-0.1.0-linux-x64-setup.sh
#
# On the machine that built the bundle it also checks that the installed program finds all its libraries.
set -uo pipefail

setup="$(realpath "${1:?usage: test-installer.sh <setup.sh>}")"
[[ -f "$setup" ]] || { echo "$setup not found" >&2; exit 1; }

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
export HOME="$home"
unset XDG_DATA_HOME XDG_CONFIG_HOME
if [[ "$(id -u)" == 0 ]]; then export WARDKEEP_ALLOW_ROOT=1; fi # a Docker run; the home folder is a temporary one anyway

failures=0
check() { # check "what" command...
  local what="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  ok    $what"; else echo "  FAIL  $what"; failures=$((failures + 1)); fi
}
refuses() { ! "$@"; }
setup_sh() { sh "$setup" "$@"; }

prefix="$HOME/.local/share/wardkeep"
desktop="$HOME/.local/share/applications/dev.omnitun.app.desktop"
icon="$HOME/.local/share/icons/hicolor/512x512/apps/dev.omnitun.app.png"
link="$HOME/.local/bin/wardkeep"

echo "== the installer refuses what it must"
check "--version prints a version" bash -c "sh '$setup' --version | grep -q '^Wardkeep '"
check "an unknown option" refuses setup_sh --nonsense
check "--purge without --uninstall" refuses setup_sh --purge
check "the home folder as the folder" refuses setup_sh --prefix "$HOME"
check "a folder with a | in it" refuses setup_sh --prefix "$HOME/a|b"
mkdir -p "$HOME/other"
touch "$HOME/other/keep"
check "a folder that is not a Wardkeep install" refuses setup_sh --prefix "$HOME/other"
check "...and that folder is untouched" test -f "$HOME/other/keep"
if [[ "$(id -u)" == 0 ]]; then
  check "root is refused" bash -c "unset WARDKEEP_ALLOW_ROOT; ! sh '$setup' 2>/dev/null"
fi

echo "== install"
check "installs" setup_sh
check "the program" test -x "$prefix/omnitun"
check "the core next to it" test -x "$prefix/omnitun-svc"
check "the uninstaller" test -x "$prefix/uninstall.sh"
check "the license" test -f "$prefix/LICENSE.txt"
check "the command is a link to the program" test "$(readlink "$link")" = "$prefix/omnitun"
check "the menu entry runs the program" grep -qx "Exec=\"$prefix/omnitun\" %U" "$desktop"
check "the menu entry has the icon name" grep -qx "Icon=dev.omnitun.app" "$desktop"
check "the menu entry offers share links" grep -q "x-scheme-handler/vless;" "$desktop"
check "the icon" test -s "$icon"
if command -v desktop-file-validate >/dev/null 2>&1; then
  check "the menu entry is valid" desktop-file-validate "$desktop"
fi
if command -v xdg-mime >/dev/null 2>&1; then
  check "vless:// opens Wardkeep" test "$(xdg-mime query default x-scheme-handler/vless)" = dev.omnitun.app.desktop
fi
if command -v ldd >/dev/null 2>&1 && LD_LIBRARY_PATH="$prefix/lib" ldd "$prefix/omnitun" >/dev/null 2>&1; then
  check "all libraries of the program are found" bash -c "! LD_LIBRARY_PATH='$prefix/lib' ldd '$prefix/omnitun' '$prefix'/lib/*.so | grep -q 'not found'"
fi

echo "== update"
touch "$prefix/stale"
check "installs over itself" setup_sh
check "the old files are gone" test ! -e "$prefix/stale"
check "the program is there again" test -x "$prefix/omnitun"

echo "== uninstall keeps the data"
mkdir -p "$HOME/.config/omnitun" "$HOME/.local/share/dev.omnitun.app"
touch "$HOME/.config/omnitun/core" "$HOME/.local/share/dev.omnitun.app/servers"
check "uninstalls" setup_sh --uninstall
check "the program is gone" test ! -e "$prefix"
check "the command is gone" test ! -e "$link"
check "the menu entry is gone" test ! -e "$desktop"
check "the icon is gone" test ! -e "$icon"
check "no link is left in mimeapps.list" bash -c "! grep -q 'dev.omnitun.app.desktop' '$HOME/.config/mimeapps.list' 2>/dev/null"
check "the settings are kept" test -f "$HOME/.local/share/dev.omnitun.app/servers"
check "the core's folder is kept" test -f "$HOME/.config/omnitun/core"
check "a second uninstall is harmless" setup_sh --uninstall

echo "== --no-links, and the uninstaller that was installed (--purge)"
check "installs without links" setup_sh --no-links
check "the menu entry offers nothing" bash -c "! grep -q '^MimeType=' '$desktop'"
check "the installed uninstaller purges" sh "$prefix/uninstall.sh" --purge
check "the program is gone" test ! -e "$prefix"
check "the settings are deleted" test ! -e "$HOME/.local/share/dev.omnitun.app"
check "the core's folder is deleted" test ! -e "$HOME/.config/omnitun"

echo "== another folder"
check "installs into --prefix" setup_sh --prefix "$HOME/apps/my wardkeep"
check "the menu entry names it" grep -qx "Exec=\"$HOME/apps/my wardkeep/omnitun\" %U" "$desktop"
check "uninstalls from there" setup_sh --uninstall --prefix "$HOME/apps/my wardkeep"
check "it is gone" test ! -e "$HOME/apps/my wardkeep"

if ((failures > 0)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
