import QtQuick

import qs.Commons

Rectangle {
  id: tab

  required property var model
  required property bool dimmed

  signal activated()
  signal closed()

  readonly property bool active: model.active

  readonly property int dotSize: 6
  readonly property int maxTextWidth: 220 - Style.gapWide * 2 - dotSize - Style.gap

  implicitWidth: Math.max(84, Math.min(220,
    Math.min(label.implicitWidth, maxTextWidth)
      + (active ? dotSize + Style.gap : 0)
      + Style.gapWide * 2))
  implicitHeight: 26
  radius: height / 2
  clip: true

  color: active
    ? Qt.rgba(1, 1, 1, 0.16)
    : (hover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
  opacity: dimmed && !active ? 0.5 : 1

  border.width: active ? Style.border : 0
  border.color: Qt.rgba(1, 1, 1, 0.16)

  Behavior on color {
    ColorAnimation { duration: Style.fast }
  }
  Behavior on opacity {
    NumberAnimation { duration: Style.fast }
  }

  HoverHandler {
    id: hover
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: tab.activated()
  }

  TapHandler {
    acceptedButtons: Qt.MiddleButton
    onTapped: tab.closed()
  }

  Row {
    anchors.centerIn: parent
    spacing: Style.gap

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: tab.dotSize
      height: tab.dotSize
      radius: tab.dotSize / 2
      color: Color.green
      visible: tab.active
    }

    Text {
      id: label

      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, tab.maxTextWidth)

      text: tab.model.title
      color: tab.active
        ? Color.foreground
        : (hover.hovered ? Color.muted : Color.faint)
      font.family: Style.font.family
      font.pixelSize: Style.font.small
      font.weight: tab.active ? Font.DemiBold : Font.Normal
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight

      Behavior on color {
        ColorAnimation { duration: Style.fast }
      }
    }
  }
}
