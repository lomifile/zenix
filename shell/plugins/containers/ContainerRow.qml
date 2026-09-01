import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// One container in the list. Two lines of text on the left for identity, two
// fixed-width numeric columns on the right for load, and a dot carrying state
// as color. The numeric columns are monospaced and right-aligned so a column
// of percentages can be scanned down rather than read across.
Rectangle {
  id: row

  required property var container
  required property bool selected
  required property bool busy

  signal activated()

  implicitHeight: 46
  radius: Style.rowRadius
  color: selected ? Color.selection : (hover.hovered ? Color.elevated : "transparent")

  Behavior on color {
    ColorAnimation { duration: Style.fast }
  }

  // Dead and exited both mean "not running", but only one of them is a
  // failure, so they do not get the same color.
  readonly property color stateColor: {
    if (row.busy) return Color.amber
    switch (container.state) {
    case "running":
      if (container.health === "unhealthy") return Color.amber
      return Color.green
    case "restarting":
    case "removing":
    case "paused":
      return Color.amber
    case "dead":
      return Color.red
    default:
      return Color.grey
    }
  }

  readonly property bool inMotion: row.busy
    || container.state === "restarting"
    || container.state === "removing"
    || container.health === "starting"

  HoverHandler {
    id: hover
  }

  TapHandler {
    onTapped: row.activated()
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.gapWide
    anchors.rightMargin: Style.gapWide
    spacing: Style.gapWide

    StatusDot {
      dotColor: row.stateColor
      pulsing: row.inMotion
      Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
      spacing: 1
      Layout.fillWidth: true
      // Without this the long image names below would push the numeric
      // columns off the right edge instead of eliding.
      Layout.minimumWidth: 0

      Text {
        text: row.container.name
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        // The image is the useful half; the status ("Up 4 hours", "Exited (0)
        // 3 days ago") is what makes a stopped container's row worth reading.
        text: row.busy
          ? row.container.image + "  ·  " + row.container.state + "ing…"
          : row.container.image + "  ·  " + row.container.status
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.small
        elide: Text.ElideMiddle
        Layout.fillWidth: true
      }
    }

    Text {
      text: row.container.ports
      color: Color.faint
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      Layout.maximumWidth: 110
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      text: row.container.cpu
      color: Color.muted
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 54
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      text: row.container.mem
      color: Color.muted
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 76
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
