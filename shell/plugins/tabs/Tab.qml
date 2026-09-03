import QtQuick
import QtQuick.Layouts

import qs.Commons

Rectangle {
  id: tab

  required property var model
  required property bool dimmed

  signal activated()
  signal closed()

  readonly property bool active: model.active

  implicitWidth: Math.max(84, Math.min(220, content.implicitWidth + Style.gapWide * 2))
  implicitHeight: 26
  radius: height / 2

  color: active
    ? Color.elevated
    : (hover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
  opacity: dimmed && !active ? 0.55 : 1

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

  RowLayout {
    id: content

    anchors.fill: parent
    anchors.leftMargin: Style.gapWide
    anchors.rightMargin: Style.gapWide
    spacing: Style.gap

    Rectangle {
      width: 5
      height: 5
      radius: 2.5
      color: Color.accent
      visible: tab.active
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      text: tab.model.title
      color: tab.active ? Color.foreground : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.small
      font.weight: tab.active ? Font.DemiBold : Font.Normal
      elide: Text.ElideRight
      Layout.fillWidth: true
      Layout.minimumWidth: 0

      Behavior on color {
        ColorAnimation { duration: Style.fast }
      }
    }
  }
}
