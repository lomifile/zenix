#!/usr/bin/env bash
#
# zenix: Xcode palette for tokyo-night-tmux.
#
# Installed over the plugin's own src/themes.sh by install.sh. The plugin ships
# four hardcoded palettes (night, storm, moon, day) and offers no hook for a
# custom one, and all twelve of its widget scripts source this file -- so owning
# it is the only way to recolour the whole bar rather than just the segments
# spelled out in tokyo-night.tmux.
#
# Every key the plugin reads anywhere is defined here, so nothing falls back to
# an empty colour. Slots are mapped by how the plugin *uses* them, not by ANSI
# name: `bblack` is a panel background in its format strings, so it takes a dark
# value rather than the bright grey ANSI would imply.

TRANSPARENT_THEME="$(tmux show-option -gv @tokyo-night-tmux_transparent)"

# >>> zenix theme <<<
declare -A THEME=(
  ["background"]="#1e1e2e"
  ["foreground"]="#cdd6f4"

  ["black"]="#45475a"
  ["red"]="#f38ba8"
  ["green"]="#a6e3a1"
  ["yellow"]="#f9e2af"
  ["blue"]="#74c7ec"
  ["magenta"]="#f5c2e7"
  ["cyan"]="#89b4fa"
  ["white"]="#cdd6f4"

  ["bblack"]="#313244"
  ["bred"]="#fab387"
  ["bgreen"]="#94e2d5"
  ["byellow"]="#f9e2af"
  ["bblue"]="#89b4fa"
  ["bmagenta"]="#b4befe"
  ["bcyan"]="#94e2d5"
  ["bwhite"]="#bac2de"

  ["ghgreen"]="#a6e3a1"
  ["ghmagenta"]="#cba6f7"
  ["ghred"]="#f38ba8"
  ["ghyellow"]="#fab387"
)
# >>> end zenix theme <<<

if [ "${TRANSPARENT_THEME}" == 1 ]; then
  THEME["background"]="default"
fi

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
