import QtQuick

import qs.Commons

Rectangle {
  id: tile

  required property var action
  required property bool selected
  required property bool armed

  signal activated()

  // The tile always carries its own colour, so shut down reads as red and
  // restart as yellow before they are selected, not only once armed.
  readonly property color tint: action.tint

  implicitWidth: 96
  implicitHeight: 96
  radius: 18

  color: selected ? Qt.rgba(1, 1, 1, 0.10) : (hover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
  border.width: selected ? 1 : 0
  border.color: selected ? tint : "transparent"

  Behavior on color {
    ColorAnimation { duration: Style.fast }
  }
  Behavior on border.color {
    ColorAnimation { duration: Style.fast }
  }

  scale: selected ? 1.0 : 0.96
  Behavior on scale {
    NumberAnimation { duration: Style.normal; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
  }

  HoverHandler {
    id: hover
  }

  TapHandler {
    onTapped: tile.activated()
  }

  Column {
    anchors.centerIn: parent
    spacing: Style.gap

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: tile.action.glyph
      color: tile.selected
        ? tile.tint
        : Qt.rgba(tile.tint.r, tile.tint.g, tile.tint.b, 0.55)
      font.family: Style.font.mono
      font.pixelSize: 30

      Behavior on color {
        ColorAnimation { duration: Style.fast }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: tile.action.label
      color: tile.selected ? Color.foreground : Color.faint
      font.family: Style.font.family
      font.pixelSize: Style.font.small
      font.weight: tile.selected ? Font.DemiBold : Font.Normal

      Behavior on color {
        ColorAnimation { duration: Style.fast }
      }
    }
  }
}
