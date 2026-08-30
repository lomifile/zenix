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
DO_PACMAN=1 DO_AUR=1 DO_DOTFILES=1 DO_SERVICES=1 DO_SHELL=1

# Names that could not be installed, reported at the end instead of aborting.
FAILED=()
# Repo-list names that turned out not to be in any repo; retried via the AUR.
AUR_EXTRA=()
# Set by install_aur_helper: whichever of yay/paru we end up driving.
AUR_HELPER=

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
      --skip-packages skip the repo package install
      --skip-aur      skip the AUR helper and the AUR package install
      --skip-dotfiles skip linking configs into ~/.config
      --skip-services skip enabling systemd units
      --skip-shell    skip oh-my-zsh, rustup and the login-shell change
  -h, --help          this message
USAGE
}

while (( $# )); do
  case "$1" in
    -n|--dry-run)     DRY_RUN=1 ;;
    --skip-packages)  DO_PACMAN=0 ;;
    --skip-aur)       DO_AUR=0 ;;
    --skip-dotfiles)  DO_DOTFILES=0 ;;
    --skip-services)  DO_SERVICES=0 ;;
    --skip-shell)     DO_SHELL=0 ;;
    -h|--help)        usage; exit 0 ;;
    *)                usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

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

link_dotfiles() {
  step "Linking dotfiles"

  # hyprland: the .lua config is the live one; hyprpaper.conf is generated
  # below because it needs an absolute wallpaper path.
  link "$REPO/hypr/hyprland.lua"  "$CONFIG/hypr/hyprland.lua"
  link "$REPO/hypr/hypridle.conf" "$CONFIG/hypr/hypridle.conf"
  link "$REPO/hypr/hyprlock.conf" "$CONFIG/hypr/hyprlock.conf"

  # waybar and wofi are renamed on the way in
  link "$REPO/waybar/waybar-config.jsonc" "$CONFIG/waybar/config.jsonc"
  link "$REPO/waybar/waybar-style.css"    "$CONFIG/waybar/style.css"
  # the cpu/memory/volume/battery modules shell out to this
  link "$REPO/waybar/scripts/statbar.sh"  "$CONFIG/waybar/scripts/statbar.sh"
  link "$REPO/wofi/config"                "$CONFIG/wofi/config"
  link "$REPO/wofi/style.css"             "$CONFIG/wofi/style.css"

  # ghostty 1.2+ reads config.ghostty, and the config pulls in auto/theme
  link "$REPO/ghostty/config.ghostty"     "$CONFIG/ghostty/config.ghostty"
  link "$REPO/ghostty/auto/theme.ghostty" "$CONFIG/ghostty/auto/theme.ghostty"

  # nvim goes in whole so lazy-lock.json stays under version control
  link "$REPO/nvim" "$CONFIG/nvim"

  # zsh reads from $ZDOTDIR, set by the ~/.zshenv written below
  link "$REPO/zsh/.zshrc" "$CONFIG/zsh/.zshrc"

  write_zshenv
  write_hyprpaper_conf
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
  local paper="$HOME/Pictures/wallpaper.png"

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

install_wallpaper() {
  local dest="$HOME/Pictures/wallpaper.png"

  if [[ -e "$dest" ]]; then
    skip "~/Pictures/wallpaper.png already present"
    return
  fi
  run mkdir -p "$HOME/Pictures"
  run cp "$REPO/assets/wallpaper.png" "$dest"
  ok "~/Pictures/wallpaper.png installed"
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
  if (( DO_SERVICES )); then enable_services; else skip "services skipped"; fi

  summary
}

main "$@"
