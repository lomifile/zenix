import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// One device in the list. Identity on the left, battery on the right, and a
// dot carrying connection state as color -- the same shape as a container row,
// so the two popups read the same way.
Rectangle {
  id: row

  required property var device
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
    if (device.connected) return Color.green
    if (device.paired) return Color.grey
    // Seen in a scan but never paired: not a failure, just not yours yet.
    return Color.faint
  }

  // bluez reports a freedesktop icon name; this is only for the label under
  // the device name, so anything unrecognised falls back to the raw value.
  readonly property string kind: {
    switch (device.icon) {
    case "audio-headset": return "Headset"
    case "audio-headphones": return "Headphones"
    case "audio-card": return "Speaker"
    case "input-keyboard": return "Keyboard"
    case "input-mouse": return "Mouse"
    case "input-gaming": return "Controller"
    case "input-tablet": return "Tablet"
    case "phone": return "Phone"
    case "computer": return "Computer"
    case "printer": return "Printer"
    case "camera-photo": return "Camera"
    case "": return "Device"
    default: return device.icon
    }
  }

  HoverHandler {
    id: hover
  }

  // One click connects, or disconnects if it is already connected.
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
        text: row.device.name
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        text: {
          if (row.busy) return row.kind + "  ·  " + (row.device.connected ? "disconnecting…" : "connecting…")
          var bits = [row.kind]
          bits.push(row.device.connected ? "connected" : (row.device.paired ? "paired" : "not paired"))
          if (row.device.paired && !row.device.trusted) bits.push("untrusted")
          return bits.join("  ·  ")
        }
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.small
        elide: Text.ElideRight
        Layout.fillWidth: true
      }
    }

    // Only connected devices report a battery, and not all of those do.
    Text {
      text: row.device.battery.length > 0 ? row.device.battery + "%" : ""
      color: {
        if (row.device.battery.length === 0) return Color.faint
        var level = parseInt(row.device.battery)
        if (level <= 15) return Color.red
        if (level <= 30) return Color.amber
        return Color.muted
      }
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 46
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
