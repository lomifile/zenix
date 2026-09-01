pragma Singleton

import QtQuick

// One palette for every shell surface. These are the values hyprlock.conf and
// waybar-style.css already use, so a popup summoned over the bar reads as part
// of the same desktop rather than as a separate app.
QtObject {
  // Surfaces. `background` is the card itself, deliberately not opaque: the
  // layer rule in hyprland.lua blurs whatever sits behind it.
  readonly property color background: "#ec1c1e21"
  readonly property color elevated: "#14ffffff"
  readonly property color scrim: "#66000000"

  // Hairlines. `border` outlines the card, `separator` divides rows inside it.
  readonly property color border: "#26ffffff"
  readonly property color separator: "#14ffffff"

  // Text. `muted` is the secondary line under a title; `faint` is for hints
  // that should register only when looked at directly.
  readonly property color foreground: "#f5f5f7"
  readonly property color muted: "#98989d"
  readonly property color faint: "#6e6e73"

  readonly property color accent: "#0a84ff"
  readonly property color selection: "#3d0a84ff"

  // Apple's dark-mode system colors. Container state is the only thing in the
  // popup carrying color, so these have to stay apart at the size of a dot.
  readonly property color green: "#30d158"
  readonly property color amber: "#ff9f0a"
  readonly property color red: "#ff453a"
  readonly property color grey: "#8e8e93"
}
