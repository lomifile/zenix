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

declare -A THEME=(
  ["background"]="#292a30"
  ["foreground"]="#dfdfe0"

  ["black"]="#414453"
  ["red"]="#ff8170"
  ["green"]="#78c2b3"
  ["yellow"]="#d9c97c"
  ["blue"]="#4eb0cc"
  ["magenta"]="#ff7ab2"
  ["cyan"]="#6bdfff"
  ["white"]="#dfdfe0"

  ["bblack"]="#393b44"
  ["bred"]="#ffa14f"
  ["bgreen"]="#acf2e4"
  ["byellow"]="#d9c97c"
  ["bblue"]="#6bdfff"
  ["bmagenta"]="#dabaff"
  ["bcyan"]="#acf2e4"
  ["bwhite"]="#a3b1bf"

  ["ghgreen"]="#78c2b3"
  ["ghmagenta"]="#b281eb"
  ["ghred"]="#ff8170"
  ["ghyellow"]="#ffa14f"
)

if [ "${TRANSPARENT_THEME}" == 1 ]; then
  THEME["background"]="default"
fi

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
