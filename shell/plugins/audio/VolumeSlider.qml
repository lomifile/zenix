import QtQuick

import qs.Commons

Item {
  id: root

  property int value: 0
  property bool muted: false
  property bool highlighted: false

  signal moved(int value)

  implicitHeight: 18

  function valueAt(x) {
    if (track.width <= 0) return 0
    return Math.max(0, Math.min(100, Math.round(x / track.width * 100)))
  }

  Rectangle {
    id: track

    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 4
    radius: 2
    color: Color.elevated

    Rectangle {
      width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
      height: parent.height
      radius: parent.radius
      color: root.muted
        ? Color.grey
        : (root.highlighted ? Color.accent : Color.muted)

      Behavior on color {
        ColorAnimation { duration: Style.fast }
      }
    }
  }

  Rectangle {
    id: handle

    width: 12
    height: 12
    radius: 6
    anchors.verticalCenter: parent.verticalCenter
    x: (track.width * Math.max(0, Math.min(100, root.value)) / 100) - width / 2

    color: root.muted ? Color.grey : Color.foreground
    opacity: root.highlighted || area.pressed || area.containsMouse ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: Style.fast }
    }
  }

  MouseArea {
    id: area

    anchors.fill: parent
    anchors.topMargin: -6
    anchors.bottomMargin: -6
    hoverEnabled: true

    onPressed: function (mouse) { root.moved(root.valueAt(mouse.x)) }
    onPositionChanged: function (mouse) { if (pressed) root.moved(root.valueAt(mouse.x)) }
    onWheel: function (wheel) {
      root.moved(root.value + (wheel.angleDelta.y > 0 ? 5 : -5))
      wheel.accepted = true
    }
  }
}
