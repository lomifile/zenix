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
  ["background"]="#24273a"
  ["foreground"]="#cad3f5"

  ["black"]="#494d64"
  ["red"]="#ed8796"
  ["green"]="#a6da95"
  ["yellow"]="#eed49f"
  ["blue"]="#7dc4e4"
  ["magenta"]="#f5bde6"
  ["cyan"]="#8aadf4"
  ["white"]="#cad3f5"

  ["bblack"]="#363a4f"
  ["bred"]="#f5a97f"
  ["bgreen"]="#8bd5ca"
  ["byellow"]="#eed49f"
  ["bblue"]="#8aadf4"
  ["bmagenta"]="#b7bdf8"
  ["bcyan"]="#8bd5ca"
  ["bwhite"]="#b8c0e0"

  ["ghgreen"]="#a6da95"
  ["ghmagenta"]="#c6a0f6"
  ["ghred"]="#ed8796"
  ["ghyellow"]="#f5a97f"
)
# >>> end zenix theme <<<

if [ "${TRANSPARENT_THEME}" == 1 ]; then
  THEME["background"]="default"
fi

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
