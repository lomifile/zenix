pragma Singleton

import QtQuick

// Spacing, type and timing shared by every surface. Sizes are logical pixels
// and left unscaled: Quickshell already hands each window its screen's device
// pixel ratio, so scaling here would apply it twice.
QtObject {
  readonly property int radius: 14
  readonly property int rowRadius: 8
  readonly property int border: 1

  readonly property int gapTight: 4
  readonly property int gap: 8
  readonly property int gapWide: 14
  readonly property int pad: 18

  readonly property QtObject font: QtObject {
    // Matches the bar and the lock screen. The fallbacks matter on a fresh
    // install, where the Apple faces are not in place until fonts are synced.
    readonly property string family: "SF Pro Display, Inter, Noto Sans, sans-serif"
    // Nerd Font glyphs and column-aligned numbers both come from here.
    readonly property string mono: "ZedMono Nerd Font, JetBrainsMono Nerd Font, monospace"
    readonly property int title: 15
    readonly property int body: 13
    readonly property int small: 11
  }

  // Fast enough that the popup feels like it was already there, slow enough to
  // read as a movement rather than a flash.
  readonly property int fast: 110
  readonly property int normal: 180
}
