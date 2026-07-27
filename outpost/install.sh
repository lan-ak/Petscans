#!/bin/sh
# Outpost installer — puts the `outpost` CLI on your PATH.
#
#   curl -fsSL https://outpost.overclock.studio/install.sh | sh
#
# Installs a single self-contained script to ~/.outpost/bin/outpost and wires it
# onto your PATH via your shell profile. Idempotent: re-running upgrades in place.
#
# Config (export before running):
#   OUTPOST_BIN        install dir              (default: $HOME/.outpost/bin)
#   OUTPOST_BASE_URL   where to fetch outpost   (default: https://outpost.overclock.studio)
#   OUTPOST_SRC        local path to copy from  (skips the download; for dev/testing)
#   OUTPOST_NO_MODIFY_PATH=1  don't touch shell profiles
#
# POSIX sh only.

set -eu

OUTPOST_BASE_URL="${OUTPOST_BASE_URL:-https://outpost.overclock.studio}"
OUTPOST_BIN="${OUTPOST_BIN:-$HOME/.outpost/bin}"
OUTPOST_SRC="${OUTPOST_SRC:-}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_BOLD="$(printf '\033[1m')"; C_DIM="$(printf '\033[2m')"
  C_GREEN="$(printf '\033[32m')"; C_YELLOW="$(printf '\033[33m')"
  C_RED="$(printf '\033[31m')"; C_BLUE="$(printf '\033[34m')"
  C_RESET="$(printf '\033[0m')"
else
  C_BOLD=; C_DIM=; C_GREEN=; C_YELLOW=; C_RED=; C_BLUE=; C_RESET=
fi
log()  { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

fetch() {
  # fetch <url> <dest>
  if [ -n "$OUTPOST_SRC" ]; then
    [ -f "$OUTPOST_SRC" ] || die "OUTPOST_SRC=$OUTPOST_SRC does not exist"
    cp "$OUTPOST_SRC" "$2"
    return 0
  fi
  if have curl; then
    curl -fsSL "$1" -o "$2" || die "download failed: $1"
  elif have wget; then
    wget -qO "$2" "$1" || die "download failed: $1"
  else
    die "need curl or wget to install (or set OUTPOST_SRC to a local copy)."
  fi
}

# Add a PATH line to the given profile if not already present.
add_path_line() {
  profile="$1"; line="$2"
  [ -f "$profile" ] || return 1
  if grep -qF "$OUTPOST_BIN" "$profile" 2>/dev/null; then
    return 0   # already wired
  fi
  printf '\n# Added by the Outpost installer\n%s\n' "$line" >> "$profile"
  ok "added outpost to PATH in $(printf '%s' "$profile" | sed "s#$HOME#~#")"
  return 0
}

wire_path() {
  case ":$PATH:" in
    *":$OUTPOST_BIN:"*) ok "$OUTPOST_BIN already on PATH"; return 0 ;;
  esac
  [ "${OUTPOST_NO_MODIFY_PATH:-0}" = "1" ] && { warn "skipping PATH edit (OUTPOST_NO_MODIFY_PATH=1)"; return 0; }

  line="export PATH=\"$OUTPOST_BIN:\$PATH\""
  touched=0
  # POSIX login shells + common interactive rc files.
  for p in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$p" ]; then add_path_line "$p" "$line" && touched=1; fi
  done
  # fish uses its own syntax and its config always exists once fish runs.
  if [ -d "$HOME/.config/fish" ]; then
    fishcfg="$HOME/.config/fish/config.fish"
    if ! grep -qF "$OUTPOST_BIN" "$fishcfg" 2>/dev/null; then
      printf '\n# Added by the Outpost installer\nfish_add_path %s\n' "$OUTPOST_BIN" >> "$fishcfg"
      ok "added outpost to PATH in ~/.config/fish/config.fish"
      touched=1
    fi
  fi
  [ "$touched" = "0" ] && warn "couldn't find a shell profile to edit — add this yourself: $line"
}

main() {
  printf '\n%s  Installing outpost%s — universal developer bootstrapper\n\n' "$C_BOLD" "$C_RESET"

  log "Installing to $OUTPOST_BIN"
  mkdir -p "$OUTPOST_BIN" || die "cannot create $OUTPOST_BIN"

  dest="$OUTPOST_BIN/outpost"
  tmp="$dest.tmp.$$"
  fetch "$OUTPOST_BASE_URL/outpost" "$tmp"

  # Sanity check: must look like the outpost script before we trust it.
  head -n1 "$tmp" | grep -q '^#!/bin/sh' || { rm -f "$tmp"; die "downloaded file is not a shell script — aborting."; }
  chmod +x "$tmp"
  mv "$tmp" "$dest"
  ok "installed $dest"

  wire_path

  ver="$("$dest" version 2>/dev/null || echo 'outpost')"
  printf '\n%s  Installed %s%s\n\n' "$C_GREEN$C_BOLD" "$ver" "$C_RESET"
  printf '%sGet started%s\n' "$C_BOLD" "$C_RESET"
  printf '  · Open a new terminal (or run: %sexport PATH="%s:$PATH"%s)\n' "$C_DIM" "$OUTPOST_BIN" "$C_RESET"
  printf '  · cd into any project and run: %soutpost%s\n' "$C_BOLD" "$C_RESET"
  printf '  · Check your toolchain:        %soutpost doctor%s\n\n' "$C_BOLD" "$C_RESET"
}

main "$@"
