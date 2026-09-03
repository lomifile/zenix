import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// One network. Same shape as a container or a bluetooth device row, so the
// three popups read the same way: dot for state, identity on the left, one
// numeric column on the right.
Rectangle {
  id: row

  required property var network
  required property bool selected
  required property bool busy

  signal activated()

  implicitHeight: 46
  radius: Style.rowRadius
  color: selected ? Color.selection : (hover.hovered ? Color.elevated : "transparent")

  Behavior on color {
    ColorAnimation { duration: Style.fast }
  }

  readonly property color stateColor: {
    if (row.busy) return Color.amber
    if (network.active) return Color.green
    if (network.known) return Color.grey
    return Color.faint
  }

  // Signal is a percentage from NetworkManager, not dBm.
  readonly property color signalColor: {
    if (network.signal >= 60) return Color.muted
    if (network.signal >= 35) return Color.amber
    return Color.red
  }

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
      pulsing: row.busy
      Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
      spacing: 1
      Layout.fillWidth: true
      Layout.minimumWidth: 0

      Text {
        text: row.network.ssid
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        text: {
          if (row.busy) return row.network.active ? "disconnecting…" : "connecting…"
          var bits = []
          if (row.network.active) bits.push("connected")
          else if (row.network.known) bits.push("saved")
          bits.push(row.network.secured ? row.network.security : "open")
          return bits.join("  ·  ")
        }
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.small
        elide: Text.ElideRight
        Layout.fillWidth: true
      }
    }

    // A lock only where it means something: an open network is the exception
    // worth spotting, so the absence of a lock is the signal.
    Text {
      text: row.network.secured ? "" : ""
      color: Color.faint
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      text: row.network.signal + "%"
      color: row.signalColor
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 44
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
