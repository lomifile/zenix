import QtQuick

import qs.Commons

// A small filled circle carrying one piece of state by color. `pulsing` is for
// states that are in motion (a container restarting, a command still running):
// the dot breathes so a stalled transition is visible as one that never stops.
Item {
  id: root

  property color dotColor: Color.grey
  property bool pulsing: false
  property int diameter: 8

  implicitWidth: diameter
  implicitHeight: diameter

  Rectangle {
    id: dot
    anchors.centerIn: parent
    width: root.diameter
    height: root.diameter
    radius: width / 2
    color: root.dotColor

    Behavior on color {
      ColorAnimation { duration: Style.normal }
    }

    SequentialAnimation on opacity {
      running: root.pulsing
      loops: Animation.Infinite
      // Ends where it started so stopping the animation never strands the dot
      // at a partial opacity.
      NumberAnimation { to: 0.35; duration: 620; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutQuad }
      onStopped: dot.opacity = 1
    }
  }
}
