#!/bin/sh
# Wardkeep for Linux: a per-user installer. It needs no root and touches nothing outside the user's own
# folders (the home folder only). build-installer.sh puts this script and the program (a tar.xz) in one file:
#
#   sh wardkeep-<version>-linux-x64-setup.sh                 install (or update) for the current user
#   sh wardkeep-<version>-linux-x64-setup.sh --uninstall     remove it again
#
# What it does, all under $HOME:
#   * the program goes to  ${XDG_DATA_HOME:-~/.local/share}/wardkeep   (--prefix DIR changes that);
#   * the command `wardkeep` is a link in ~/.local/bin;
#   * a menu entry (dev.omnitun.app.desktop) and its icon, in ~/.local/share/applications and icons;
#   * unless --no-links: Wardkeep becomes the program for share links (vless://, vmess://, ...) and is
#     offered for VPN config files (.ovpn, .conf, .json, .yaml, .txt) under "Open with";
#   * the uninstaller is kept next to the program (<prefix>/uninstall.sh).
# The uninstaller removes all of that and keeps your servers and settings, unless it is given --purge.
#
# The two @...@ values below are filled in when the installer is built.

set -eu

VERSION="@VERSION@"
PAYLOAD_SHA256="@PAYLOAD_SHA256@"
APP_ID="dev.omnitun.app"
APP_ID_RE='dev\.omnitun\.app'
MARKER=".wardkeep-install"

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Wardkeep $VERSION for Linux (per-user installer)

Usage: sh $(basename "$0") [options]

  (no option)      install or update Wardkeep for the current user
  --uninstall      remove Wardkeep; your servers and settings are kept
  --purge          with --uninstall: delete your servers and settings too
  --prefix DIR     install into DIR (default: ~/.local/share/wardkeep)
  --no-links       do not take over share links (vless://, ...) and do not offer config files
  --version        print the version
  -h, --help       this text

Run it as yourself, not as root: it installs for one user only.
EOF
}

MODE=install
# The copy kept next to the program (<prefix>/uninstall.sh) only uninstalls.
[ "$(basename "$0")" = uninstall.sh ] && MODE=uninstall
PURGE=0
LINKS=1
PREFIX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) MODE=uninstall ;;
    --purge) PURGE=1 ;;
    --no-links) LINKS=0 ;;
    --prefix)
      [ $# -ge 2 ] || die "--prefix needs a folder"
      PREFIX=$2
      shift
      ;;
    --prefix=*) PREFIX=${1#--prefix=} ;;
    --version) say "Wardkeep $VERSION"; exit 0 ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done
if [ "$PURGE" = 1 ] && [ "$MODE" != uninstall ]; then die "--purge goes with --uninstall"; fi

[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set"
if [ "$(id -u)" = 0 ] && [ -z "${WARDKEEP_ALLOW_ROOT:-}" ]; then
  die "this installs for one user, in their home folder: run it as that user, not as root (no sudo)"
fi

DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
BIN_DIR=$HOME/.local/bin
DESKTOP_FILE=$DATA_HOME/applications/$APP_ID.desktop
ICON_FILE=$DATA_HOME/icons/hicolor/512x512/apps/$APP_ID.png
LINK=$BIN_DIR/wardkeep
MIMEAPPS=$CONFIG_HOME/mimeapps.list

# The uninstaller kept in <prefix>/uninstall.sh works on the folder it is in.
if [ -z "$PREFIX" ] && [ "$MODE" = uninstall ] && [ -f "$(dirname "$0")/$MARKER" ]; then
  PREFIX=$(cd "$(dirname "$0")" && pwd)
fi
[ -n "$PREFIX" ] || PREFIX=$DATA_HOME/wardkeep
case "$PREFIX" in /*) ;; *) PREFIX=$(pwd)/$PREFIX ;; esac
while [ "${#PREFIX}" -gt 1 ] && [ "${PREFIX%/}" != "$PREFIX" ]; do PREFIX=${PREFIX%/}; done
# The folder ends up in the menu entry and in sed commands: keep it to plain characters.
if printf '%s' "$PREFIX" | LC_ALL=C grep -q '[|&\\"`$%;]' || [ "$(printf '%s' "$PREFIX" | wc -l)" != 0 ]; then
  die "the folder may not contain | & \\ \" \` \$ % ; or a line break: $PREFIX"
fi
[ "$PREFIX" != / ] && [ "$PREFIX" != "$HOME" ] || die "not a folder to install into: $PREFIX"

# The line where the program (tar.xz) starts; empty in the uninstaller copy.
payload_line() { awk '$0 == "__WARDKEEP_PAYLOAD__" { print NR + 1; exit }' "$0"; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is needed but not installed"; }

# Libraries the program links to that this system lacks: a warning, not a stop (they can be installed later).
check_libraries() {
  command -v ldd >/dev/null 2>&1 || return 0
  missing=$(LD_LIBRARY_PATH="$1/lib" ldd "$1/omnitun" "$1"/lib/*.so 2>/dev/null |
    sed -n 's/^[[:space:]]*\(.*\) => not found.*/\1/p' | sort -u)
  [ -z "$missing" ] && return 0
  warn "these libraries are missing, and Wardkeep will not start without them:"
  printf '  %s\n' $missing >&2
  warn "Debian/Ubuntu: sudo apt install libgtk-3-0 libayatana-appindicator3-1 libnotify4"
  warn "Fedora:        sudo dnf install gtk3 libayatana-appindicator-gtk3 libnotify"
  warn "Arch:          sudo pacman -S gtk3 libayatana-appindicator libnotify"
}

install_app() {
  need tar
  need xz
  need awk
  need mktemp
  start=$(payload_line)
  [ -n "$start" ] || die "there is no program in this file: download the installer file and run it from there"

  case "$PAYLOAD_SHA256" in
    "" | @*) ;;
    *)
      if command -v sha256sum >/dev/null 2>&1; then
        got=$(tail -n +"$start" "$0" | sha256sum | cut -d ' ' -f 1)
        [ "$got" = "$PAYLOAD_SHA256" ] || die "the installer file is damaged (wrong checksum): download it again"
      fi
      ;;
  esac

  parent=$(dirname "$PREFIX")
  mkdir -p "$parent"
  stage=$(mktemp -d "$parent/.wardkeep-setup.XXXXXX")
  trap 'rm -rf "$stage"' EXIT
  trap 'exit 1' INT TERM HUP

  say "Unpacking Wardkeep $VERSION ..."
  tail -n +"$start" "$0" | tar -xJf - -C "$stage"
  [ -x "$stage/app/omnitun" ] && [ -x "$stage/app/omnitun-svc" ] || die "the installer is incomplete (the program or its core is missing)"
  check_libraries "$stage/app"

  if [ -e "$PREFIX" ]; then
    [ -f "$PREFIX/$MARKER" ] || die "$PREFIX exists and is not a Wardkeep install: choose another folder with --prefix"
    old="$PREFIX.old.$$"
    mv "$PREFIX" "$old" || die "could not replace $PREFIX"
    if ! mv "$stage/app" "$PREFIX"; then
      mv "$old" "$PREFIX"
      die "could not install into $PREFIX"
    fi
    rm -rf "$old"
  else
    mv "$stage/app" "$PREFIX" || die "could not install into $PREFIX"
  fi

  {
    echo "version=$VERSION"
    echo "links=$LINKS"
    echo "desktop=$DESKTOP_FILE"
    echo "icon=$ICON_FILE"
    echo "link=$LINK"
  } >"$PREFIX/$MARKER"
  head -n "$((start - 1))" "$0" >"$PREFIX/uninstall.sh"
  chmod 755 "$PREFIX/uninstall.sh"

  # The command.
  mkdir -p "$BIN_DIR"
  if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
    warn "$LINK exists and is not a link: left alone"
  else
    ln -sfn "$PREFIX/omnitun" "$LINK"
  fi

  # The menu entry and its icon.
  mkdir -p "$(dirname "$DESKTOP_FILE")" "$(dirname "$ICON_FILE")"
  cp "$stage/wardkeep.png" "$ICON_FILE"
  new="$DESKTOP_FILE.new.$$"
  sed -e "s|^Exec=.*|Exec=\"$PREFIX/omnitun\" %U|" -e "s|^Icon=.*|Icon=$APP_ID|" "$stage/$APP_ID.desktop" |
    if [ "$LINKS" = 1 ]; then cat; else sed '/^MimeType=/d'; fi >"$new"
  mv "$new" "$DESKTOP_FILE"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
  fi

  # Share links: the same list the menu entry offers.
  if [ "$LINKS" = 1 ]; then
    if command -v xdg-mime >/dev/null 2>&1; then
      schemes=$(sed -n 's/^MimeType=//p' "$DESKTOP_FILE" | tr ';' '\n' | sed -n 's|^x-scheme-handler/||p')
      for s in $schemes; do
        xdg-mime default "$APP_ID.desktop" "x-scheme-handler/$s" || warn "could not register $s:// links"
      done
    else
      warn "xdg-mime (xdg-utils) is not installed: share links were not registered"
    fi
  fi

  say "Wardkeep $VERSION is installed in $PREFIX"
  say "  start it from the application menu, or run: wardkeep"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say "  ($BIN_DIR is not in your PATH; use $PREFIX/omnitun)" ;;
  esac
  say "  remove it with: sh $PREFIX/uninstall.sh [--purge]"
}

marker_value() { sed -n "s/^$1=//p" "$PREFIX/$MARKER" | head -n 1; }

uninstall_app() {
  if [ -f "$PREFIX/$MARKER" ]; then
    if command -v pgrep >/dev/null 2>&1 && pgrep -u "$(id -u)" -f "$PREFIX/omnitun" >/dev/null 2>&1; then
      warn "Wardkeep is running: it keeps running until it is closed"
    fi
    desktop=$(marker_value desktop)
    case "$desktop" in */$APP_ID.desktop) ;; *) desktop=$DESKTOP_FILE ;; esac
    icon=$(marker_value icon)
    case "$icon" in */$APP_ID.png) ;; *) icon=$ICON_FILE ;; esac
    link=$(marker_value link)
    case "$link" in */wardkeep) ;; *) link=$LINK ;; esac

    [ "$(readlink "$link" 2>/dev/null || true)" = "$PREFIX/omnitun" ] && rm -f "$link"
    rm -f "$desktop" "$icon"
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database -q "$(dirname "$desktop")" 2>/dev/null || true
    fi
    # The links this install took over: only the lines that name Wardkeep.
    if [ -f "$MIMEAPPS" ] && grep -q "=$APP_ID_RE.desktop" "$MIMEAPPS"; then
      tmp="$MIMEAPPS.new.$$"
      sed "\|^x-scheme-handler/[^=]*=$APP_ID_RE\.desktop;\{0,1\}\$|d" "$MIMEAPPS" >"$tmp" && cat "$tmp" >"$MIMEAPPS"
      rm -f "$tmp"
    fi
    rm -rf "$PREFIX"
    say "Wardkeep is removed from $PREFIX"
  else
    say "Wardkeep is not installed in $PREFIX"
  fi

  data="$DATA_HOME/$APP_ID $DATA_HOME/omnitun $CONFIG_HOME/omnitun"
  if [ "$PURGE" = 1 ]; then
    for d in $data; do
      if [ -d "$d" ]; then
        rm -rf "$d"
        say "deleted $d"
      fi
    done
  else
    for d in $data; do
      [ -d "$d" ] && say "kept your servers and settings in $d (--purge deletes them)"
    done
  fi
  return 0
}

if [ "$MODE" = uninstall ]; then uninstall_app; else install_app; fi
exit 0
__WARDKEEP_PAYLOAD__
