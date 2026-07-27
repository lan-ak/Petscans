#!/bin/sh
# Outpost — one-line developer bootstrap for PetScans.
#
#   curl -fsSL https://outpost.overclock.studio/install.sh | sh
#
# What it does (idempotent, safe to re-run):
#   1. Verifies the host toolchain (git, node >= 18, npm), installing what it
#      can via the platform package manager.
#   2. Clones the PetScans repo (or reuses an existing checkout).
#   3. Installs Node dependencies for the backend and the tooling packages.
#   4. Seeds backend/.dev.vars from the example so `wrangler dev` is one step away.
#
# It never prints or commits secrets, and never runs a deploy. Everything is
# configurable with environment variables (see CONFIG below).
#
# POSIX sh only — no bashisms — so it runs under `sh` when piped from curl.

set -eu

# ----------------------------------------------------------------------------
# CONFIG (override by exporting before piping, e.g. `OUTPOST_DIR=~/code sh`)
# ----------------------------------------------------------------------------
OUTPOST_REPO="${OUTPOST_REPO:-https://github.com/lan-ak/Petscans.git}"
OUTPOST_BRANCH="${OUTPOST_BRANCH:-main}"
OUTPOST_DIR="${OUTPOST_DIR:-$HOME/Petscans}"
OUTPOST_SKIP_CLONE="${OUTPOST_SKIP_CLONE:-0}"      # 1 = use current dir, don't clone
OUTPOST_SKIP_INSTALL="${OUTPOST_SKIP_INSTALL:-0}"  # 1 = don't run npm install
MIN_NODE_MAJOR=18

# ----------------------------------------------------------------------------
# Pretty output (fall back to plain text when not a TTY / no color support)
# ----------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_BOLD="$(printf '\033[1m')"; C_DIM="$(printf '\033[2m')"
  C_RED="$(printf '\033[31m')"; C_GREEN="$(printf '\033[32m')"
  C_YELLOW="$(printf '\033[33m')"; C_BLUE="$(printf '\033[34m')"
  C_RESET="$(printf '\033[0m')"
else
  C_BOLD=; C_DIM=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_RESET=
fi

log()   { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%serror%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }
step()  { printf '%s  ·%s %s\n' "$C_DIM" "$C_RESET" "$*"; }

have()  { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------
# Platform + package-manager detection
# ----------------------------------------------------------------------------
OS="$(uname -s 2>/dev/null || echo unknown)"
PKG=""              # the package-manager command we found
PKG_INSTALL=""      # the sub-command to install a package
detect_pkg() {
  if [ "$OS" = "Darwin" ] && have brew; then
    PKG="brew"; PKG_INSTALL="brew install"
  elif have apt-get; then
    PKG="apt-get"; PKG_INSTALL="sudo apt-get install -y"
  elif have dnf; then
    PKG="dnf"; PKG_INSTALL="sudo dnf install -y"
  elif have pacman; then
    PKG="pacman"; PKG_INSTALL="sudo pacman -S --noconfirm"
  elif have apk; then
    PKG="apk"; PKG_INSTALL="sudo apk add"
  fi
}

# Install a package by name, or explain how if we can't.
ensure_pkg() {
  tool="$1"; pkg="${2:-$1}"
  if have "$tool"; then return 0; fi
  if [ -z "$PKG" ]; then
    if [ "$OS" = "Darwin" ]; then
      die "$tool is missing and Homebrew was not found. Install Homebrew (https://brew.sh) then re-run, or install $tool manually."
    fi
    die "$tool is missing and no supported package manager was found. Install $tool manually, then re-run."
  fi
  warn "$tool not found — installing with $PKG"
  if [ "$PKG" = "apt-get" ]; then sudo apt-get update -y >/dev/null 2>&1 || true; fi
  # shellcheck disable=SC2086
  $PKG_INSTALL "$pkg" || die "failed to install $tool via $PKG — install it manually and re-run."
  have "$tool" || die "$tool still not on PATH after install."
  ok "installed $tool"
}

node_major() { node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }

# ----------------------------------------------------------------------------
# Steps
# ----------------------------------------------------------------------------
banner() {
  printf '\n%s  Outpost%s — PetScans developer bootstrap\n' "$C_BOLD" "$C_RESET"
  printf '%s  %s (%s)%s\n\n' "$C_DIM" "$OS" "$(uname -m 2>/dev/null || echo '?')" "$C_RESET"
}

check_toolchain() {
  log "Checking toolchain"
  detect_pkg
  [ -n "$PKG" ] && step "package manager: $PKG" || step "no package manager detected (will only verify)"

  ensure_pkg git
  ok "git $(git --version 2>/dev/null | awk '{print $3}')"

  if ! have node; then
    # Prefer a nodejs package; names differ across distros but this covers most.
    case "$PKG" in
      brew)   ensure_pkg node node ;;
      apt-get|dnf|pacman) ensure_pkg node nodejs ;;
      apk)    ensure_pkg node nodejs ;;
      *)      ensure_pkg node nodejs ;;
    esac
  fi
  have node || die "node is required but could not be installed automatically. See https://nodejs.org."

  major="$(node_major)"
  if [ "$major" -lt "$MIN_NODE_MAJOR" ]; then
    die "node $MIN_NODE_MAJOR+ required, found $(node --version). Upgrade node (e.g. via nvm: https://github.com/nvm-sh/nvm) and re-run."
  fi
  ok "node $(node --version)"

  ensure_pkg npm npm 2>/dev/null || true
  have npm || die "npm is required but was not found (usually bundled with node)."
  ok "npm $(npm --version)"

  if [ "$OS" = "Darwin" ]; then
    if have xcodebuild; then
      ok "xcodebuild present (iOS app buildable)"
    else
      warn "xcodebuild not found — install Xcode from the App Store to build the iOS app (backend/tools still work)."
    fi
  else
    step "non-macOS host: the Node backend + tools are supported; the iOS app needs a Mac with Xcode."
  fi
}

fetch_repo() {
  if [ "$OUTPOST_SKIP_CLONE" = "1" ]; then
    OUTPOST_DIR="$(pwd)"
    log "Using current directory (OUTPOST_SKIP_CLONE=1): $OUTPOST_DIR"
    return 0
  fi

  # Already inside a PetScans checkout? Reuse it.
  if [ -f "PetScans.xcodeproj/project.pbxproj" ] || { [ -d .git ] && [ -d backend ] && [ -f backend/wrangler.toml ]; }; then
    OUTPOST_DIR="$(pwd)"
    log "Detected an existing PetScans checkout: $OUTPOST_DIR"
    return 0
  fi

  log "Fetching PetScans into $OUTPOST_DIR"
  if [ -d "$OUTPOST_DIR/.git" ]; then
    step "existing clone found — updating"
    git -C "$OUTPOST_DIR" fetch --quiet origin "$OUTPOST_BRANCH" \
      && git -C "$OUTPOST_DIR" checkout --quiet "$OUTPOST_BRANCH" \
      && git -C "$OUTPOST_DIR" pull --quiet --ff-only origin "$OUTPOST_BRANCH" \
      || warn "could not fast-forward existing clone; leaving it as-is"
  else
    git clone --branch "$OUTPOST_BRANCH" "$OUTPOST_REPO" "$OUTPOST_DIR" \
      || die "clone failed. If the repo is private, authenticate git first (e.g. 'gh auth login' or an SSH key) and re-run."
  fi
  ok "repository ready at $OUTPOST_DIR"
}

npm_install_dir() {
  dir="$1"
  if [ ! -f "$OUTPOST_DIR/$dir/package.json" ]; then
    step "skip $dir (no package.json)"; return 0
  fi
  step "npm install — $dir"
  ( cd "$OUTPOST_DIR/$dir" && npm install --no-fund --no-audit ) \
    || die "npm install failed in $dir"
  ok "dependencies installed — $dir"
}

install_deps() {
  if [ "$OUTPOST_SKIP_INSTALL" = "1" ]; then
    log "Skipping dependency install (OUTPOST_SKIP_INSTALL=1)"; return 0
  fi
  log "Installing Node dependencies"
  npm_install_dir backend
  npm_install_dir tools/meta
  npm_install_dir tools/petcatalog
}

seed_env() {
  example="$OUTPOST_DIR/backend/.dev.vars.example"
  target="$OUTPOST_DIR/backend/.dev.vars"
  [ -f "$example" ] || return 0
  log "Setting up backend secrets file"
  if [ -f "$target" ]; then
    ok "backend/.dev.vars already exists (left untouched)"
  else
    cp "$example" "$target"
    ok "created backend/.dev.vars from the example — fill in your keys"
  fi
}

next_steps() {
  printf '\n%s  All set.%s PetScans is ready in %s%s%s\n\n' \
    "$C_GREEN$C_BOLD" "$C_RESET" "$C_BOLD" "$OUTPOST_DIR" "$C_RESET"
  printf '%sNext steps%s\n' "$C_BOLD" "$C_RESET"
  printf '  1. cd %s/backend\n' "$OUTPOST_DIR"
  printf '  2. Edit .dev.vars — set AUTH_SECRET (openssl rand -hex 32) and the provider keys\n'
  printf '  3. npm test        %s# vitest unit + router tests%s\n' "$C_DIM" "$C_RESET"
  printf '  4. npm run dev     %s# wrangler dev (local Worker)%s\n' "$C_DIM" "$C_RESET"
  if [ "$OS" = "Darwin" ]; then
    printf '  5. open %s/PetScans.xcodeproj  %s# build the iOS app in Xcode%s\n' "$OUTPOST_DIR" "$C_DIM" "$C_RESET"
  fi
  printf '\n%sDocs:%s backend/README.md · docs/SETUP.md\n\n' "$C_DIM" "$C_RESET"
}

main() {
  banner
  check_toolchain
  fetch_repo
  install_deps
  seed_env
  next_steps
}

main "$@"
