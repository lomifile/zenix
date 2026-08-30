#!/usr/bin/env bash
#
# Install yay, the AUR helper.
#
# Standalone — install.sh calls it, but it also runs on its own:
#
#     ./scripts/install-yay.sh              # yay-bin, prebuilt, no Go needed
#     ./scripts/install-yay.sh --from-source # build yay from source
#
# Idempotent: exits early if yay is already on PATH.

set -euo pipefail

PKG=yay-bin
DRY_RUN=0

if [[ -t 1 ]]; then
  B=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; BLU=$'\e[34m'; N=$'\e[0m'
else
  B= DIM= RED= GRN= YLW= BLU= N=
fi

step() { printf '\n%s==>%s %s%s%s\n' "$BLU" "$N" "$B" "$*" "$N"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$GRN" "$N" "$*"; }
skip() { printf '    %s·%s %s\n' "$DIM" "$N" "$*"; }
warn() { printf '    %s!%s %s\n' "$YLW" "$N" "$*" >&2; }
die()  { printf '\n%serror:%s %s\n' "$RED" "$N" "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then
    printf '    %s$ %s%s\n' "$DIM" "$*" "$N"
  else
    "$@"
  fi
}

usage() {
  cat <<'USAGE'
usage: ./scripts/install-yay.sh [options]

      --from-source  build the `yay` package instead of the prebuilt `yay-bin`
                     (slower, and pulls in Go as a make dependency)
  -n, --dry-run      print what would happen, change nothing
  -h, --help         this message
USAGE
}

while (( $# )); do
  case "$1" in
    --from-source) PKG=yay ;;
    -n|--dry-run)  DRY_RUN=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

step "Installing yay ($PKG)"

(( EUID != 0 )) || die "run this as your normal user, not root — makepkg refuses to build as root."
command -v pacman >/dev/null || die "pacman not found; this script only targets Arch."

if command -v yay >/dev/null; then
  skip "yay already installed ($(yay --version 2>/dev/null | head -1))"
  exit 0
fi

(( DRY_RUN )) && warn "dry run — nothing will be changed." || sudo -v

# makepkg needs the toolchain, and git needs to exist before we clone with it.
info "ensuring base-devel and git are present"
run sudo pacman -S --needed --noconfirm base-devel git

BUILD="$(mktemp -d)"
# Leave the tree behind on failure so the build log can be read.
cleanup() { (( $? == 0 )) && rm -rf "$BUILD" || warn "build tree kept at $BUILD"; }
trap cleanup EXIT

info "cloning $PKG into $BUILD"
run git clone --depth 1 "https://aur.archlinux.org/$PKG.git" "$BUILD/$PKG"

info "building and installing $PKG"
if (( DRY_RUN )); then
  printf '    %s$ (cd %s/%s && makepkg -si --noconfirm)%s\n' "$DIM" "$BUILD" "$PKG" "$N"
else
  ( cd "$BUILD/$PKG" && makepkg -si --noconfirm ) || die "$PKG build failed"
fi

ok "yay installed"
