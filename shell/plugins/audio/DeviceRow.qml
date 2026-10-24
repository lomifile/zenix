import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

Rectangle {
  id: row

  required property var device
  required property bool selected
  required property bool isDefault
  required property bool busy
  required property int volume

  signal activated()
  signal muteToggled()
  signal volumeRequested(int value)

  implicitHeight: 60
  radius: Style.rowRadius
  color: selected ? Theme.selection : (hover.hovered ? Theme.elevated : "transparent")

  Behavior on color {
    ColorAnimation { duration: Style.fast }
  }

  readonly property color stateColor: {
    if (row.busy) return Theme.amber
    if (row.device.mute) return Theme.red
    if (row.isDefault) return Theme.green
    return Theme.faint
  }

  readonly property string detail: {
    if (row.busy) return "switching…"
    var bits = []
    bits.push(row.isDefault ? "default" : "available")
    if (row.device.mute) bits.push("muted")
    if (row.device.state === "RUNNING") bits.push("in use")
    return bits.join("  ·  ")
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
      spacing: 3
      Layout.fillWidth: true
      Layout.minimumWidth: 0

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.gap

        Text {
          text: row.device.description
          color: Theme.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: row.detail
          color: Theme.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.gap

        Text {
          text: row.device.mute ? "󰝟" : (row.volume === 0 ? "󰕿" : (row.volume < 50 ? "󰖀" : "󰕾"))
          color: row.device.mute ? Theme.red : Theme.muted
          font.family: Style.font.mono
          font.pixelSize: Style.font.body

          TapHandler {
            onTapped: row.muteToggled()
          }
        }

        VolumeSlider {
          Layout.fillWidth: true
          value: row.volume
          muted: row.device.mute
          highlighted: row.selected
          onMoved: function (value) { row.volumeRequested(value) }
        }

        Text {
          text: row.volume + "%"
          color: row.device.mute ? Theme.faint : Theme.muted
          font.family: Style.font.mono
          font.pixelSize: Style.font.small
          horizontalAlignment: Text.AlignRight
          Layout.preferredWidth: 38
        }
      }
    }
  }
}
