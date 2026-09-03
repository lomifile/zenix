#!/usr/bin/env bash
#
# zenix — post-install bootstrap for a fresh Arch Linux system.
#
# Run this as your normal user (not root) on the first boot after archinstall
# has laid the system down with user_configuration.json:
#
#     pacman -S --needed git
#     git clone <this repo> ~/build/zenix && cd ~/build/zenix && ./install.sh
#
# It is idempotent: re-running installs only what is missing and re-points only
# dotfiles that have drifted. Anything it replaces is backed up first.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

DRY_RUN=0
DO_PACMAN=1 DO_AUR=1 DO_DOTFILES=1 DO_SERVICES=1 DO_SHELL=1 DO_SDDM=1 DO_CLI=1 DO_TOOLS=1 DO_WEBAPPS=1 DO_GRUB=1

# Names that could not be installed, reported at the end instead of aborting.
FAILED=()
# Repo-list names that turned out not to be in any repo; retried via the AUR.
AUR_EXTRA=()
# Set by install_aur_helper: whichever of yay/paru we end up driving.
AUR_HELPER=
# The image hyprpaper shows on the desktop, picked by name out of
# assets/wallpaper/; SRC/DEST are filled in by resolve_wallpaper.
WALLPAPER_NAME="azoc6k1g99mh1.png"
WALLPAPER_SRC= WALLPAPER_DEST=
# The greeter gets its own, picked by name out of assets/wallpaper/.
GREETER_WALLPAPER_NAME="couple-bus-sunset.jpg"
GREETER_WALLPAPER_SRC= GREETER_WALLPAPER_DEST=

# ---------------------------------------------------------------- output ----

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
usage: ./install.sh [options]

  -n, --dry-run       print what would happen, change nothing
      --configs-only  only copy configuration: dotfiles, the greeter theme,
                      the web apps, the agenda timer and the GRUB theme.
                      Installs no packages and builds nothing.
      --skip-packages skip the repo package install
      --skip-aur      skip the AUR helper and the AUR package install
      --skip-dotfiles skip linking configs into ~/.config
      --skip-services skip enabling systemd units
      --skip-shell    skip oh-my-zsh, rustup and the login-shell change
      --skip-sddm     skip installing the greeter theme
      --skip-cli      skip building the zenix CLI
      --skip-tools    skip pnpm and Claude Code
      --skip-webapps  skip installing the browser web apps
      --skip-grub     skip installing the GRUB theme
  -h, --help          this message
USAGE
}

while (( $# )); do
  case "$1" in
    -n|--dry-run)     DRY_RUN=1 ;;
    # Everything that writes configuration, nothing that installs software.
    # Listed before the --skip-* cases on purpose: a later --skip-grub (or
    # any other) still overrides it, so the two compose.
    --configs-only)   DO_PACMAN=0 DO_AUR=0 DO_SHELL=0 DO_TOOLS=0 DO_CLI=0 DO_SERVICES=0 ;;
    --skip-packages)  DO_PACMAN=0 ;;
    --skip-aur)       DO_AUR=0 ;;
    --skip-dotfiles)  DO_DOTFILES=0 ;;
    --skip-services)  DO_SERVICES=0 ;;
    --skip-shell)     DO_SHELL=0 ;;
    --skip-sddm)      DO_SDDM=0 ;;
    --skip-cli)       DO_CLI=0 ;;
    --skip-tools)     DO_TOOLS=0 ;;
    --skip-webapps)   DO_WEBAPPS=0 ;;
    --skip-grub)      DO_GRUB=0 ;;
    -h|--help)        usage; exit 0 ;;
    *)                usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

# -------------------------------------------------------------- wallpaper ----

# assets/wallpaper/ is a collection, so one of them has to be nominated as the
# active image. Override the choice with ZENIX_WALLPAPER=/path/to/image.
resolve_wallpaper() {
  if [[ -n "${ZENIX_WALLPAPER:-}" ]]; then
    WALLPAPER_SRC="$ZENIX_WALLPAPER"
  elif [[ -f "$REPO/assets/wallpaper/$WALLPAPER_NAME" ]]; then
    WALLPAPER_SRC="$REPO/assets/wallpaper/$WALLPAPER_NAME"
  else
    warn "assets/wallpaper/$WALLPAPER_NAME missing; falling back to the first image"
    # Prefer png/jpg: hyprpaper reads webp fine, but the greeter falls back to
    # this image and Qt needs qt6-imageformats for webp, which pacman.txt omits.
    WALLPAPER_SRC="$(find "$REPO/assets/wallpaper" -maxdepth 1 -type f \
                       \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
                     2>/dev/null | sort | head -1)"
    [[ -n "$WALLPAPER_SRC" ]] || WALLPAPER_SRC="$(find "$REPO/assets/wallpaper" \
                                   -maxdepth 1 -type f 2>/dev/null | sort | head -1)"
  fi

  if [[ -z "$WALLPAPER_SRC" || ! -f "$WALLPAPER_SRC" ]]; then
    WALLPAPER_SRC="" WALLPAPER_DEST=""
    return
  fi
  WALLPAPER_DEST="$HOME/Pictures/wallpaper/$(basename "$WALLPAPER_SRC")"
}

# The login screen is its own surface, so it does not have to match the desktop.
# Override with ZENIX_GREETER_WALLPAPER=/path/to/image.
resolve_greeter_wallpaper() {
  if [[ -n "${ZENIX_GREETER_WALLPAPER:-}" ]]; then
    GREETER_WALLPAPER_SRC="$ZENIX_GREETER_WALLPAPER"
  elif [[ -f "$REPO/assets/wallpaper/$GREETER_WALLPAPER_NAME" ]]; then
    GREETER_WALLPAPER_SRC="$REPO/assets/wallpaper/$GREETER_WALLPAPER_NAME"
  else
    warn "assets/wallpaper/$GREETER_WALLPAPER_NAME missing; greeter falls back to the desktop wallpaper"
    GREETER_WALLPAPER_SRC="$WALLPAPER_SRC"
  fi

  if [[ -f "$GREETER_WALLPAPER_SRC" ]]; then
    # install_wallpaper syncs the whole collection here, so hyprlock can read
    # it without depending on the root-owned copy in the sddm theme directory.
    GREETER_WALLPAPER_DEST="$HOME/Pictures/wallpaper/$(basename "$GREETER_WALLPAPER_SRC")"
  else
    GREETER_WALLPAPER_SRC="" GREETER_WALLPAPER_DEST=""
  fi
}

# -------------------------------------------------------------- preflight ----

preflight() {
  step "Preflight"

  (( EUID != 0 )) || die "run this as your normal user, not root — it uses sudo where it needs to."
  command -v pacman >/dev/null || die "pacman not found; this script only targets Arch."
  [[ -f "$REPO/packages/pacman.txt" ]] || die "packages/pacman.txt missing — run this from inside the repo."

  if [[ ! -f /etc/arch-release ]]; then
    warn "/etc/arch-release is missing; this does not look like Arch. Continuing anyway."
  fi

  ping -c1 -W3 archlinux.org >/dev/null 2>&1 || warn "no route to archlinux.org — package steps will likely fail."

  resolve_wallpaper
  resolve_greeter_wallpaper
  if [[ -n "$WALLPAPER_SRC" ]]; then
    info "paper:   $(basename "$WALLPAPER_SRC") (desktop)"
  else
    warn "no image in assets/wallpaper/; hyprpaper will be blank"
  fi
  [[ -n "$GREETER_WALLPAPER_SRC" ]] \
    && info "greeter: $(basename "$GREETER_WALLPAPER_SRC")" \
    || warn "no greeter wallpaper; the login screen falls back to a flat colour"

  info "repo:    $REPO"
  info "configs: $CONFIG"
  info "backups: $BACKUP"

  (( DRY_RUN )) && warn "dry run — nothing will be changed." || true

  # Take the sudo prompt now rather than in the middle of a long build.
  (( DRY_RUN )) || sudo -v
}

# --------------------------------------------------------------- packages ----

# Uncomment multilib (the lib32-* packages need it) and turn on the niceties
# archinstall's pacman_config asked for.
configure_pacman() {
  step "Configuring /etc/pacman.conf"

  if grep -qE '^\s*\[multilib\]' /etc/pacman.conf; then
    skip "multilib already enabled"
  else
    info "enabling multilib"
    run sudo sed -i '/^#\[multilib\]$/{s/^#//; n; s/^#//}' /etc/pacman.conf
  fi

  grep -qE '^\s*Color' /etc/pacman.conf \
    && skip "Color already set" \
    || run sudo sed -i 's/^#\s*Color/Color/' /etc/pacman.conf

  if grep -qE '^\s*ParallelDownloads' /etc/pacman.conf; then
    skip "ParallelDownloads already set"
  else
    run sudo sed -i 's/^#\s*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
  fi

  info "synchronising package databases"
  run sudo pacman -Syu --noconfirm
}

# Read a package list, dropping comments and blank lines.
read_list() {
  grep -vE '^\s*(#|$)' "$1" | tr -d ' \t'
}

# Every package and group name the configured repos offer, cached once — a
# `pacman -Si` per name would be a few hundred process spawns.
declare -A REPO_NAMES=()

cache_repo_names() {
  local n
  while read -r n; do REPO_NAMES["$n"]=1; done < <(pacman -Slq 2>/dev/null)
  while read -r n _; do REPO_NAMES["$n"]=1; done < <(pacman -Sg 2>/dev/null)
}

in_repos() {
  [[ -n "${REPO_NAMES[$1]:-}" ]]
}

install_repo_packages() {
  step "Installing repo packages"

  local want=() from_repo=() not_in_repo=() p
  cache_repo_names
  mapfile -t want < <(read_list "$REPO/packages/pacman.txt")
  info "${#want[@]} names in packages/pacman.txt"

  for p in "${want[@]}"; do
    if in_repos "$p"; then from_repo+=("$p"); else not_in_repo+=("$p"); fi
  done

  if (( ${#from_repo[@]} )); then
    info "${#from_repo[@]} available in the configured repos"
    if ! run sudo pacman -S --needed --noconfirm "${from_repo[@]}"; then
      # One bad name shouldn't sink the batch — retry individually to find it.
      warn "batch install failed; retrying one at a time"
      for p in "${from_repo[@]}"; do
        run sudo pacman -S --needed --noconfirm "$p" || FAILED+=("$p (repo)")
      done
    fi
  fi

  if (( ${#not_in_repo[@]} )); then
    # packages/pacman.txt is checked against core/extra/multilib, so this
    # should be empty — it catches names that were dropped or renamed upstream.
    warn "${#not_in_repo[@]} not in any repo, deferring to the AUR: ${not_in_repo[*]}"
    AUR_EXTRA+=("${not_in_repo[@]}")
  fi
}

install_aur_helper() {
  step "Setting up the AUR helper"

  # An existing helper is left alone — no reason to build a second one.
  local h
  for h in yay paru; do
    if command -v "$h" >/dev/null; then
      AUR_HELPER="$h"
      skip "$h already installed"
      return
    fi
  done

  local args=()
  (( DRY_RUN )) && args+=(--dry-run) || true
  run_script "$REPO/scripts/install-yay.sh" "${args[@]}"
  AUR_HELPER=yay
}

# The yay installer prints its own step header, so call it directly rather than
# through run() even on a dry run — it honours --dry-run itself.
run_script() {
  local script="$1"; shift
  [[ -x "$script" ]] || die "missing or not executable: $script"
  "$script" "$@" || die "$(basename "$script") failed"
}

install_aur_packages() {
  step "Installing AUR packages"

  local want=() p
  if [[ -z "$AUR_HELPER" ]]; then
    warn "no AUR helper available; skipping AUR packages"
    return
  fi
  info "using $AUR_HELPER"
  mapfile -t want < <(read_list "$REPO/packages/aur.txt")
  want+=("${AUR_EXTRA[@]}")

  # One at a time: a single unbuildable package should not block the rest.
  for p in "${want[@]}"; do
    [[ -n "$p" ]] || continue
    if pacman -Qq "$p" >/dev/null 2>&1; then
      skip "$p already installed"
      continue
    fi
    info "building $p"
    case "$AUR_HELPER" in
      yay)  run yay  -S --needed --noconfirm --answerdiff=None --answeredit=None --removemake "$p" || FAILED+=("$p (aur)") ;;
      paru) run paru -S --needed --noconfirm --skipreview "$p" || FAILED+=("$p (aur)") ;;
      *)    FAILED+=("$p (aur — no helper)") ;;
    esac
  done
}

# --------------------------------------------------------------- dotfiles ----

# Point $2 at $1, stashing whatever is already there.
link() {
  local src="$1" dest="$2"

  [[ -e "$src" ]] || { warn "missing in repo, skipping: $src"; return; }

  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    skip "${dest/#$HOME/\~} already linked"
    return
  fi

  run mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" || -L "$dest" ]]; then
    local stash="$BACKUP/${dest#$HOME/}"
    info "backing up ${dest/#$HOME/\~}"
    run mkdir -p "$(dirname "$stash")"
    run mv "$dest" "$stash"
  fi

  run ln -sfn "$src" "$dest"
  ok "${dest/#$HOME/\~} -> ${src/#$REPO/repo}"
}

retire() {
  local dest="$1" why="$2"

  [[ -e "$dest" || -L "$dest" ]] || return

  local stash="$BACKUP/${dest#$HOME/}"
  info "retiring ${dest/#$HOME/\~} ($why)"
  run mkdir -p "$(dirname "$stash")"
  run mv "$dest" "$stash"
}

link_dotfiles() {
  step "Linking dotfiles"

  retire "$CONFIG/hypr/hyprland.conf" "superseded by hyprland.lua"
  retire "$CONFIG/wofi/power.sh"      "superseded by zenix-shell"
  retire "$CONFIG/wofi/bluetooth.sh"  "superseded by zenix-shell"

  # hyprland: the .lua config is the live one; hyprpaper.conf is generated
  # below because it needs an absolute wallpaper path.
  link "$REPO/hypr/hyprland.lua"  "$CONFIG/hypr/hyprland.lua"
  link "$REPO/hypr/hypridle.conf" "$CONFIG/hypr/hypridle.conf"

  # waybar and wofi are renamed on the way in
  link "$REPO/waybar/waybar-config.jsonc" "$CONFIG/waybar/config.jsonc"
  link "$REPO/waybar/waybar-style.css"    "$CONFIG/waybar/style.css"
  # linked as a directory so new scripts are picked up without editing this
  # list; the modules shell out to statbar.sh and agenda.py
  link "$REPO/waybar/scripts"             "$CONFIG/waybar/scripts"
  link "$REPO/wofi/config"                "$CONFIG/wofi/config"
  link "$REPO/wofi/style.css"             "$CONFIG/wofi/style.css"

  # ghostty 1.2+ reads config.ghostty, and the config pulls in auto/theme
  link "$REPO/ghostty/config.ghostty"     "$CONFIG/ghostty/config.ghostty"
  link "$REPO/ghostty/auto/theme.ghostty" "$CONFIG/ghostty/auto/theme.ghostty"

  # nvim goes in whole so lazy-lock.json stays under version control
  link "$REPO/nvim" "$CONFIG/nvim"

  # zenix-shell, linked as a directory so a new plugin under shell/plugins is
  # found by the next restart without this list having to learn about it.
  # hyprland.lua starts it with `qs -p ~/.config/zenix/shell`.
  link "$REPO/shell" "$CONFIG/zenix/shell"

  # The IPC wrapper every keybind goes through. On PATH rather than in
  # ~/.config, because it is a command, not configuration.
  run mkdir -p "$HOME/.local/bin"
  link "$REPO/bin/zenix-shell" "$HOME/.local/bin/zenix-shell"

  # zsh reads from $ZDOTDIR, set by the ~/.zshenv written below
  link "$REPO/zsh/.zshrc" "$CONFIG/zsh/.zshrc"

  write_zshenv
  write_hyprpaper_conf
  write_hyprlock_conf
  install_wallpaper
}

# Generated rather than linked: the repo copy would hardcode one username, and
# the cargo line has to tolerate rustup not being installed yet.
write_zshenv() {
  local dest="$HOME/.zshenv"

  if [[ -e "$dest" && ! -L "$dest" ]] && ! grep -q 'zenix' "$dest" 2>/dev/null; then
    info "backing up ~/.zshenv"
    run mkdir -p "$BACKUP"
    run cp "$dest" "$BACKUP/.zshenv"
  fi

  if (( DRY_RUN )); then
    printf '    %s$ write %s%s\n' "$DIM" "$dest" "$N"
  else
    cat > "$dest" <<'ZSHENV'
# Generated by zenix install.sh. Always read first by zsh, regardless of
# ZDOTDIR. Its only job is to point the rest of zsh's startup files
# (.zprofile, .zshrc, .zlogin) at the XDG location instead of $HOME.
export ZDOTDIR="$HOME/.config/zsh"
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
ZSHENV
  fi
  ok "~/.zshenv written"
}

# hyprpaper has no $HOME expansion, so the path has to be baked in.
write_hyprpaper_conf() {
  local dest="$CONFIG/hypr/hyprpaper.conf"
  local paper="$WALLPAPER_DEST"

  if [[ -z "$paper" ]]; then
    warn "skipping hyprpaper.conf: no wallpaper resolved"
    return
  fi

  run mkdir -p "$CONFIG/hypr"
  if (( DRY_RUN )); then
    printf '    %s$ write %s (wallpaper %s)%s\n' "$DIM" "$dest" "$paper" "$N"
  else
    sed -e "s|^preload = .*|preload = $paper|" \
        -e "s|^wallpaper = .*|wallpaper = , $paper|" \
        "$REPO/hypr/hyprpaper.conf" > "$dest"
  fi
  ok "~/.config/hypr/hyprpaper.conf written"
}

# hyprlock has no $HOME expansion either, and it shows the greeter's image so
# the lock screen and the login screen are the same surface.
write_hyprlock_conf() {
  local dest="$CONFIG/hypr/hyprlock.conf"

  if [[ -z "$GREETER_WALLPAPER_DEST" ]]; then
    warn "no greeter wallpaper resolved; linking hyprlock.conf unchanged"
    link "$REPO/hypr/hyprlock.conf" "$dest"
    return
  fi

  run mkdir -p "$CONFIG/hypr"
  if (( DRY_RUN )); then
    printf '    %s$ write %s (background %s)%s\n' "$DIM" "$dest" "$GREETER_WALLPAPER_DEST" "$N"
  else
    sed -e "s|^\([[:space:]]*\)path = .*|\1path = $GREETER_WALLPAPER_DEST|" \
        "$REPO/hypr/hyprlock.conf" > "$dest"
  fi
  ok "~/.config/hypr/hyprlock.conf written"
}

install_wallpaper() {
  if [[ ! -d "$REPO/assets/wallpaper" ]]; then
    warn "assets/wallpaper/ missing; nothing to install"
    return
  fi

  run mkdir -p "$HOME/Pictures/wallpaper"
  run cp -rn "$REPO/assets/wallpaper/." "$HOME/Pictures/wallpaper/"
  ok "~/Pictures/wallpaper/ synced ($(find "$REPO/assets/wallpaper" -type f | wc -l) files)"

  [[ -n "$WALLPAPER_DEST" ]] && ok "active: ${WALLPAPER_DEST/#$HOME/\~}" || true
}

# ------------------------------------------------------------------ shell ----

setup_shell() {
  step "Setting up the shell"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    skip "oh-my-zsh already installed"
  else
    info "installing oh-my-zsh (unattended)"
    if (( DRY_RUN )); then
      printf '    %s$ sh -c "$(curl -fsSL .../install.sh)" "" --unattended --keep-zshrc%s\n' "$DIM" "$N"
    else
      # --keep-zshrc: our own .zshrc is already linked and sources oh-my-zsh
      RUNZSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc || FAILED+=("oh-my-zsh")
    fi
  fi

  # .zshenv sources ~/.cargo/env, which rustup creates on first toolchain install
  if command -v rustup >/dev/null && [[ ! -f "$HOME/.cargo/env" ]]; then
    info "installing the stable rust toolchain"
    run rustup default stable || FAILED+=("rustup default stable")
  else
    skip "rust toolchain already set up"
  fi

  local zsh_bin
  zsh_bin="$(command -v zsh || true)"
  if [[ -z "$zsh_bin" ]]; then
    warn "zsh is not installed; leaving the login shell alone"
  elif [[ "${SHELL:-}" == "$zsh_bin" ]]; then
    skip "login shell is already zsh"
  else
    info "changing the login shell to $zsh_bin"
    run sudo chsh -s "$zsh_bin" "$USER" || FAILED+=("chsh to zsh")
  fi
}

# ------------------------------------------------------------------- grub ----

# Set or replace a KEY=value in /etc/default/grub, uncommenting it if needed.
set_grub_default() {
  local key="$1" value="$2" file=/etc/default/grub

  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
    run sudo sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}=.*|${key}=${value}|" "$file"
  else
    run sudo sed -i "\$a ${key}=${value}" "$file"
  fi
  ok "/etc/default/grub: ${key}=${value}"
}

install_grub_theme() {
  step "Installing the GRUB theme"

  if [[ ! -d "$REPO/grub/theme" ]]; then
    skip "no grub/theme directory"
    return
  fi
  if [[ ! -d /boot/grub ]]; then
    warn "/boot/grub missing — GRUB is not installed here; skipping the theme"
    return
  fi

  local dest=/boot/grub/themes/zenix
  run sudo install -d -m 755 /boot/grub/themes "$dest" "$dest/icons"

  # install(1) cannot copy a directory, so the entry icons in theme/icons are
  # walked separately -- globbing theme/* alone silently skipped them.
  local f
  for f in "$REPO"/grub/theme/*; do
    [[ -f "$f" ]] || continue
    run sudo install -m 644 "$f" "$dest/$(basename "$f")"
  done
  for f in "$REPO"/grub/theme/icons/*; do
    [[ -f "$f" ]] || continue
    run sudo install -m 644 "$f" "$dest/icons/$(basename "$f")"
  done
  ok "theme copied to $dest"

  run sudo cp -n /etc/default/grub /etc/default/grub.zenix-backup

  set_grub_default GRUB_THEME "\"$dest/theme.txt\""

  # A theme is only ever drawn if the menu is actually shown. Manjaro ships
  # GRUB_TIMEOUT_STYLE=hidden, which boots straight through and never renders
  # it.
  set_grub_default GRUB_TIMEOUT_STYLE menu

  # Themes are drawn by gfxterm and nothing else. grub-mkconfig defaults to it
  # when the value is empty, but a GRUB_TERMINAL= line anywhere in the file
  # sets both halves and would silently select the text console, so pin it.
  set_grub_default GRUB_TERMINAL_OUTPUT gfxterm
  if grep -qE '^[[:space:]]*GRUB_TERMINAL=' /etc/default/grub; then
    warn "GRUB_TERMINAL= is set and overrides GRUB_TERMINAL_OUTPUT; comment it out"
  fi

  # gfxterm has to actually get a video mode. "auto" is enough on real
  # hardware, but VirtualBox's GOP advertises a short mode list and the probe
  # can fail, dropping GRUB back to the plain text menu with no error — the
  # theme then simply never appears. A fallback chain fixes that and costs
  # nothing on bare metal, where the first entry usually matches the panel.
  set_grub_default GRUB_GFXMODE "1920x1080x32,1280x1024x32,1024x768x32,auto"

  info "regenerating /boot/grub/grub.cfg"
  if ! run sudo grub-mkconfig -o /boot/grub/grub.cfg; then
    warn "grub-mkconfig failed; the theme is installed but not active"
    FAILED+=("grub theme (grub-mkconfig)")
    return
  fi

  verify_grub_theme
}

# grub-mkconfig exits 0 whether or not it picked the theme up, so check the
# generated config rather than trusting it. Without this the installer reports
# success and the machine still boots to the plain text menu.
verify_grub_theme() {
  local cfg=/boot/grub/grub.cfg

  if (( DRY_RUN )); then
    printf '    %s$ (verify %s references the theme)%s\n' "$DIM" "$cfg" "$N"
    return
  fi

  # grub.cfg is mode 600 root, so read it once through sudo; grepping it
  # directly as the user fails on every pattern and looks like a broken theme.
  local content
  if ! content="$(sudo cat "$cfg" 2>/dev/null)"; then
    warn "cannot read $cfg; skipping verification"
    return
  fi

  local missing=()
  grep -q '^insmod gfxmenu'  <<<"$content" || missing+=("insmod gfxmenu")
  grep -q '^set theme='      <<<"$content" || missing+=("set theme=")
  grep -q 'themes/zenix'     <<<"$content" || missing+=("a themes/zenix path")
  grep -qE '^[[:space:]]*loadfont.*zenix.*\.pf2' <<<"$content" \
    || missing+=("loadfont for the theme fonts")

  if (( ${#missing[@]} == 0 )); then
    ok "verified: grub.cfg loads the theme"
    info "$(grep -m1 '^set theme=' <<<"$content")"
    return
  fi

  warn "grub-mkconfig ran but $cfg does not reference the theme"
  warn "missing: ${missing[*]}"
  warn "the machine will boot to the plain text menu. Checking why:"

  local theme_line
  theme_line="$(grep -E '^[[:space:]]*GRUB_THEME=' /etc/default/grub || true)"
  warn "  GRUB_THEME is: ${theme_line:-<unset>}"

  grep -qE '^[[:space:]]*GRUB_TERMINAL_OUTPUT=gfxterm' /etc/default/grub \
    || warn "  GRUB_TERMINAL_OUTPUT is not gfxterm — only gfxterm draws themes"
  grep -qE '^[[:space:]]*GRUB_TERMINAL=' /etc/default/grub \
    && warn "  GRUB_TERMINAL= is set and overrides GRUB_TERMINAL_OUTPUT" || true
  [[ -r /boot/grub/themes/zenix/theme.txt ]] \
    || warn "  /boot/grub/themes/zenix/theme.txt is missing or unreadable"

  # 00_header drops the theme silently when grub-probe cannot describe the
  # filesystem holding it.
  if command -v grub-probe >/dev/null; then
    sudo grub-probe -t fs /boot/grub/themes/zenix/theme.txt >/dev/null 2>&1 \
      || warn "  grub-probe cannot read the filesystem holding the theme"
  fi

  FAILED+=("grub theme (not referenced in grub.cfg)")
}

# -------------------------------------------------------------------- cli ----

# Built from cli/ and installed with pipx, so the CLI gets its own venv instead
# of fighting Arch's externally-managed system Python (PEP 668).
# Build one of the repo's Python projects and install it with pipx, which
# gives each its own venv instead of fighting Arch's externally-managed system
# Python (PEP 668). Extra pipx flags are passed through for projects that need
# --system-site-packages so the venv can import gi from python-gobject.
build_python_project() {
  local dir="$1" binary="$2"; shift 2
  local pipx_args=("$@")

  if ! python3 -c 'import build' 2>/dev/null; then
    warn "python-build missing; skipping $binary (it is in packages/pacman.txt)"
    FAILED+=("$binary (no python-build)")
    return 1
  fi

  # --no-isolation: build against the repo packages rather than pulling a
  # toolchain from PyPI into a throwaway env.
  if (( DRY_RUN )); then
    printf '    %s$ (cd %s && python3 -m build --wheel --no-isolation)%s\n' "$DIM" "$dir" "$N"
  else
    ( cd "$dir" && rm -rf dist && python3 -m build --wheel --no-isolation ) \
      || { warn "$binary: wheel build failed"; FAILED+=("$binary (build)"); return 1; }
  fi

  local wheel
  wheel="$(find "$dir/dist" -name '*.whl' 2>/dev/null | sort | tail -1)"
  if [[ -z "$wheel" ]] && ! (( DRY_RUN )); then
    warn "$binary: no wheel produced"
    FAILED+=("$binary (no wheel)")
    return 1
  fi

  if command -v pipx >/dev/null || (( DRY_RUN )); then
    run pipx install --force "${pipx_args[@]}" "${wheel:-$dir}" \
      || { FAILED+=("$binary (pipx)"); return 1; }
  else
    warn "pipx missing; installing $binary into a venv under ~/.local/share"
    local venv="$HOME/.local/share/$binary"
    run python3 -m venv "${pipx_args[@]}" "$venv"
    run "$venv/bin/pip" install --quiet "$wheel"
    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "$venv/bin/$binary" "$HOME/.local/bin/$binary"
  fi

  ok "$binary installed to ~/.local/bin/$binary"
}

# sddm merges /etc/sddm.conf.d/* in sorted order with the last file winning, so
# a theme can be installed correctly and still never appear. Name the file that
# actually decides it rather than trusting the prefix.
verify_sddm_theme() {
  if (( DRY_RUN )); then
    printf '    %s$ (verify no later conf.d file overrides Current=)%s\n' "$DIM" "$N"
    return
  fi

  local winner="" file
  for file in $(ls /etc/sddm.conf.d/ 2>/dev/null | sort); do
    grep -qE '^[[:space:]]*Current[[:space:]]*=' "/etc/sddm.conf.d/$file" && winner="$file"
  done

  if [[ "$winner" == "zz-zenix.conf" ]]; then
    ok "verified: zz-zenix.conf has the last word on Current="
  else
    warn "$winner sorts after zz-zenix.conf and also sets Current= —"
    warn "the greeter will use its theme, not zenix. Rename or remove it."
    FAILED+=("sddm theme (overridden by $winner)")
  fi
}

# ---------------------------------------------------------------- webapps ----

# Browser web apps, declared as plain .desktop files under webapps/.
#
# Brave's own "Install app" flow writes Exec=... --app-id=<hash>, which only
# resolves against the PWA registry inside one Brave profile, and an Icon= name
# keyed to the same hash. Neither exists on a fresh machine, so those entries
# launch nothing. Declaring --app=<url> here instead keeps them reproducible,
# and --class= gives the window an app_id that hyprland rules can match.
# The waybar agenda module reads a cache; this is what refreshes it.
install_agenda_timer() {
  step "Installing the agenda timer"

  local src="$REPO/systemd"
  if [[ ! -d "$src" ]]; then
    skip "no systemd/ directory"
    return
  fi

  local dest="$CONFIG/systemd/user"
  run mkdir -p "$dest"
  local f
  for f in "$src"/*.service "$src"/*.timer; do
    [[ -e "$f" ]] || continue
    run install -m 644 "$f" "$dest/$(basename "$f")"
  done

  run systemctl --user daemon-reload
  enable_user_unit zenix-agenda.timer
  # Populate the cache now so the bar is not blank until the first firing.
  run systemctl --user start zenix-agenda.service || true
  ok "agenda cache refreshes every 5 minutes"
}

install_webapps() {
  step "Installing web apps"

  local src="$REPO/webapps"
  if [[ ! -d "$src" ]]; then
    skip "no webapps/ directory"
    return
  fi

  local entries=()
  shopt -s nullglob
  entries=("$src"/*.desktop)
  local icon_files=("$src"/icons/*.png)
  shopt -u nullglob

  if (( ${#entries[@]} == 0 )); then
    skip "no web apps declared"
    return
  fi

  if ! command -v brave >/dev/null; then
    warn "brave not installed; the launchers will appear but will not start"
  fi

  local apps="$HOME/.local/share/applications"
  local hicolor="$HOME/.local/share/icons/hicolor"
  run mkdir -p "$apps" "$hicolor/512x512/apps"

  local f
  for f in "${entries[@]}"; do
    run install -m 644 "$f" "$apps/$(basename "$f")"
    ok "$(basename "$f" .desktop)"
  done
  for f in "${icon_files[@]}"; do
    run install -m 644 "$f" "$hicolor/512x512/apps/$(basename "$f")"
  done

  # Without these the launcher and the icon may not show up until the next login.
  if command -v update-desktop-database >/dev/null; then
    run update-desktop-database "$apps"
  fi
  if command -v gtk-update-icon-cache >/dev/null; then
    run gtk-update-icon-cache -qtf "$hicolor"
  fi

  info "${#entries[@]} web app(s) installed to ~/.local/share/applications"
}

# ------------------------------------------------------------- user tools ----

# pnpm and Claude Code are installed with their own installers rather than from
# the repos or the AUR, because both self-update in place and both land in
# ~/.local, which is where this setup already looks for them: zsh/.zshrc exports
# PNPM_HOME=~/.local/share/pnpm and puts ~/.local/bin on PATH.

# Run a shell pipeline that `run` cannot express as an argv list.
run_pipeline() {
  if (( DRY_RUN )); then
    printf '    %s$ %s%s\n' "$DIM" "$1" "$N"
    return 0
  fi
  bash -c "$1"
}

install_pnpm() {
  if command -v pnpm >/dev/null; then
    skip "pnpm already installed ($(pnpm --version 2>/dev/null))"
    return
  fi

  info "installing pnpm"
  # SHELL is pinned to bash so pnpm's installer appends its PATH block to
  # ~/.bashrc instead of ~/.config/zsh/.zshrc — that file is a symlink into
  # this repo, and zsh/.zshrc already sets PNPM_HOME and the PATH entry.
  if run_pipeline 'curl -fsSL https://get.pnpm.io/install.sh | SHELL=/bin/bash PNPM_HOME="$HOME/.local/share/pnpm" sh -'; then
    ok "pnpm installed to ~/.local/share/pnpm"
  else
    warn "pnpm install failed"
    FAILED+=("pnpm")
  fi
}

install_claude_code() {
  if command -v claude >/dev/null; then
    skip "claude already installed ($(claude --version 2>/dev/null | head -1))"
    return
  fi

  info "installing Claude Code"
  if run_pipeline 'curl -fsSL https://claude.ai/install.sh | bash'; then
    ok "claude installed to ~/.local/bin/claude"
  else
    warn "Claude Code install failed"
    FAILED+=("claude-code")
  fi
}

install_user_tools() {
  step "Installing user tooling"

  if ! command -v curl >/dev/null; then
    warn "curl missing; skipping pnpm and Claude Code"
    FAILED+=("pnpm, claude-code (no curl)")
    return
  fi

  install_pnpm
  install_claude_code
}

# -------------------------------------------------------------------- cli ----

# Built from cli/ and installed with pipx, so the CLI gets its own venv instead
# of fighting Arch's externally-managed system Python (PEP 668).
install_cli() {
  step "Building the zenix CLI"

  if ! command -v python3 >/dev/null; then
    warn "python3 missing; skipping the CLI"
    return
  fi
  if ! python3 -c 'import build' 2>/dev/null; then
    warn "python-build missing; skipping the CLI (it is in packages/pacman.txt)"
    return
  fi

  # --no-isolation: build against the repo packages rather than pulling a
  # toolchain from PyPI into a throwaway env.
  if (( DRY_RUN )); then
    printf '    %s$ (cd %s/cli && python3 -m build --wheel --no-isolation)%s\n' "$DIM" "$REPO" "$N"
  else
    ( cd "$REPO/cli" && rm -rf dist && python3 -m build --wheel --no-isolation ) \
      || { warn "wheel build failed; skipping the CLI"; FAILED+=("zenix cli (build)"); return; }
  fi

  local wheel
  wheel="$(find "$REPO/cli/dist" -name 'zenix-*.whl' 2>/dev/null | sort | tail -1)"
  if [[ -z "$wheel" ]] && ! (( DRY_RUN )); then
    warn "no wheel produced; skipping the CLI"
    FAILED+=("zenix cli (no wheel)")
    return
  fi

  if command -v pipx >/dev/null || (( DRY_RUN )); then
    run pipx install --force "${wheel:-$REPO/cli}" || FAILED+=("zenix cli (pipx)")
  else
    warn "pipx missing; installing into a venv at ~/.local/share/zenix instead"
    run python3 -m venv "$HOME/.local/share/zenix"
    run "$HOME/.local/share/zenix/bin/pip" install --quiet "$wheel"
    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "$HOME/.local/share/zenix/bin/zenix" "$HOME/.local/bin/zenix"
  fi

  ok "zenix installed to ~/.local/bin/zenix"
  info "run 'zenix status' from anywhere; it finds the repo via \$ZENIX_REPO or --repo"
}

# ------------------------------------------------------------------- sddm ----

# The theme has to be copied rather than symlinked: sddm runs as its own user
# and $HOME is 0700, so it cannot follow a link back into the repo.
install_sddm_theme() {
  step "Installing the SDDM greeter theme"

  if ! command -v sddm >/dev/null && ! pacman -Qq sddm >/dev/null 2>&1; then
    skip "sddm not installed"
    return
  fi

  local dest=/usr/share/sddm/themes/zenix

  run sudo install -d -m 755 "$dest"
  local f
  for f in "$REPO"/sddm/zenix/*; do
    run sudo install -m 644 "$f" "$dest/$(basename "$f")"
  done

  # the greeter cannot read ~/Pictures either, so the wallpaper ships with it
  if [[ -n "$GREETER_WALLPAPER_SRC" ]]; then
    run sudo install -m 644 "$GREETER_WALLPAPER_SRC" "$dest/background.png"
  else
    warn "no wallpaper resolved; the greeter falls back to a flat colour"
  fi

  run sudo install -d -m 755 /etc/sddm.conf.d
  run sudo install -m 644 "$REPO/sddm/conf.d/zz-zenix.conf" /etc/sddm.conf.d/zz-zenix.conf
  # Earlier versions shipped this as 99-zenix.conf, which loses to
  # kde_settings.conf on a sorted read.
  [[ -e /etc/sddm.conf.d/99-zenix.conf ]] && run sudo rm -f /etc/sddm.conf.d/99-zenix.conf

  ok "greeter theme installed to $dest"
  verify_sddm_theme
}

# --------------------------------------------------------------- services ----

unit_exists() {
  systemctl list-unit-files "$1" >/dev/null 2>&1 \
    && [[ -n "$(systemctl list-unit-files --no-legend "$1" 2>/dev/null)" ]]
}

enable_system_unit() {
  local unit="$1"
  if ! unit_exists "$unit"; then
    skip "$unit not installed"
    return
  fi
  if [[ "$(systemctl is-enabled "$unit" 2>/dev/null)" == "enabled" ]]; then
    skip "$unit already enabled"
    return
  fi
  if run sudo systemctl enable "$unit"; then ok "$unit enabled"; else FAILED+=("$unit"); fi
}

enable_user_unit() {
  local unit="$1"
  if [[ -z "$(systemctl --user list-unit-files --no-legend "$unit" 2>/dev/null)" ]]; then
    skip "$unit (user) not installed"
    return
  fi
  if [[ "$(systemctl --user is-enabled "$unit" 2>/dev/null)" == "enabled" ]]; then
    skip "$unit (user) already enabled"
    return
  fi
  if run systemctl --user enable "$unit"; then ok "$unit (user) enabled"; else FAILED+=("$unit (user)"); fi
}

enable_services() {
  step "Enabling services"

  local unit
  for unit in NetworkManager.service bluetooth.service sddm.service cronie.service \
              systemd-timesyncd.service avahi-daemon.service acpid.service \
              power-profiles-daemon.service docker.service tailscaled.service \
              cups.socket ufw.service; do
    enable_system_unit "$unit"
  done

  for unit in pipewire.socket pipewire-pulse.socket wireplumber.service \
              xdg-user-dirs.service; do
    enable_user_unit "$unit"
  done

  # tlp and power-profiles-daemon both want to drive power policy; ppd is the
  # one asusctl integrates with, so tlp stays installed but disabled.
  if unit_exists tlp.service && [[ "$(systemctl is-enabled tlp.service 2>/dev/null)" == "enabled" ]]; then
    warn "tlp.service is enabled and will fight power-profiles-daemon; disabling it"
    run sudo systemctl disable tlp.service
  fi

  if getent group docker >/dev/null && ! id -nG "$USER" | grep -qw docker; then
    info "adding $USER to the docker group"
    run sudo usermod -aG docker "$USER"
  else
    skip "docker group membership already set"
  fi

  run xdg-user-dirs-update || true
}

# ---------------------------------------------------------------- summary ----

summary() {
  step "Done"

  if (( ${#FAILED[@]} )); then
    warn "${#FAILED[@]} item(s) did not install:"
    printf '      - %s\n' "${FAILED[@]}" >&2
    echo
  fi

  cat <<EOF
    Next steps:

      1. Reboot, or start Hyprland from a TTY, to pick up the new session.
      2. sudo ufw enable          — the service is on, the ruleset is not.
      3. Log out and back in for the docker group to take effect.
      4. Open nvim once and let lazy.nvim sync against nvim/lazy-lock.json.
      5. gcalcli init          — the waybar clock popup needs Google OAuth,
                                 which cannot be scripted. Until you run it,
                                 the popup says "Authentication required.".

    Anything replaced is in ${BACKUP/#$HOME/\~}
EOF
}

# ------------------------------------------------------------------- main ----

main() {
  preflight

  if (( DO_PACMAN )); then
    configure_pacman
    install_repo_packages
  else
    skip "packages skipped"
  fi

  if (( DO_AUR )); then
    install_aur_helper
    install_aur_packages
  else
    skip "AUR skipped"
  fi

  if (( DO_DOTFILES )); then link_dotfiles;   else skip "dotfiles skipped"; fi
  if (( DO_SHELL ));    then setup_shell;     else skip "shell setup skipped"; fi
  if (( DO_SDDM ));     then install_sddm_theme; else skip "sddm theme skipped"; fi
  if (( DO_TOOLS ));    then install_user_tools; else skip "user tooling skipped"; fi
  if (( DO_WEBAPPS )); then install_webapps; install_agenda_timer;
                       else skip "web apps skipped"; fi
  if (( DO_GRUB ));    then install_grub_theme; else skip "grub theme skipped"; fi
  if (( DO_CLI ));      then install_cli;        else skip "cli skipped"; fi
  if (( DO_SERVICES )); then enable_services; else skip "services skipped"; fi

  summary
}

main "$@"
