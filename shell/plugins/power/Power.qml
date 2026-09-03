import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property int index: 0
  property bool armed: false

  readonly property var actions: [
    {
      id: "lock",
      label: "Lock",
      glyph: "󰌾",
      key: Qt.Key_L,
      confirm: false,
      tint: Color.accent,
      command: ["hyprlock"],
    },
    {
      id: "logout",
      label: "Log Out",
      glyph: "󰍃",
      key: Qt.Key_O,
      confirm: true,
      tint: Color.amber,
      command: ["hyprctl", "dispatch", "hl.dsp.exit()"],
    },
    {
      id: "sleep",
      label: "Sleep",
      glyph: "󰒲",
      key: Qt.Key_S,
      confirm: false,
      tint: Color.accent,
      command: ["systemctl", "suspend"],
    },
    {
      id: "restart",
      label: "Restart",
      glyph: "󰜉",
      key: Qt.Key_R,
      confirm: true,
      tint: Color.yellow,
      command: ["systemctl", "reboot"],
    },
    {
      id: "shutdown",
      label: "Shut Down",
      glyph: "󰐥",
      key: Qt.Key_P,
      confirm: true,
      tint: Color.red,
      command: ["systemctl", "poweroff"],
    },
  ]

  readonly property var current: actions[index]

  // $HOSTNAME is a shell variable and is usually not exported, so it is read
  // from the file the shell itself reads.
  property string hostname: ""
  readonly property string who: Quickshell.env("USER") + (hostname.length > 0 ? "@" + hostname : "")

  FileView {
    path: "/etc/hostname"
    onLoaded: root.hostname = text().trim()
  }

  function open(payload) {
    index = 0
    armed = false
    opened = true
  }

  function close() {
    opened = false
    armed = false
  }

  function move(delta) {
    armed = false
    index = (index + delta + actions.length) % actions.length
  }

  function choose(i) {
    if (i !== index) {
      index = i
      armed = false
    }

    if (current.confirm && !armed) {
      armed = true
      return
    }

    run(current)
  }

  function run(action) {
    root.close()
    Quickshell.execDetached(action.command)
  }

  // Arrows and Tab only: every letter is an action shortcut, so h/l cannot also
  // mean movement without `l` being both "right" and "Lock".
  function handleKey(event) {
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
      move(-1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
      move(1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      choose(index)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Escape && armed) {
      armed = false
      event.accepted = true
      return
    }

    for (var i = 0; i < actions.length; i++) {
      if (event.key === actions[i].key) {
        choose(i)
        event.accepted = true
        return
      }
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-power"
    cardWidth: 620
    cardHeight: 260

    onDismissed: root.close()
    onKeyPressed: function (event) { root.handleKey(event) }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.bottomMargin: 0
        spacing: Style.gap

        Text {
          text: root.armed ? root.current.label + "?" : "Session"
          color: root.armed ? root.current.tint : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold

          Behavior on color {
            ColorAnimation { duration: Style.fast }
          }
        }

        Item { Layout.fillWidth: true }

        Text {
          text: root.armed ? "this cannot be undone" : root.who
          color: Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          elide: Text.ElideRight
          Layout.maximumWidth: 260
        }
      }

      Item { Layout.fillHeight: true }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.gapWide

        Repeater {
          model: root.actions

          delegate: PowerTile {
            required property var modelData
            required property int index

            action: modelData
            selected: index === root.index
            armed: root.armed && index === root.index

            onActivated: root.choose(index)
          }
        }
      }

      Item { Layout.fillHeight: true }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.topMargin: Style.gap
        Layout.bottomMargin: Style.gap
        spacing: Style.gapWide

        KeyHint {
          key: "⏎"
          label: root.armed ? "confirm " + root.current.label.toLowerCase() : "select"
        }
        KeyHint { key: "←→"; label: "move" }

        Item { Layout.fillWidth: true }

        KeyHint { key: "esc"; label: root.armed ? "cancel" : "close" }
      }
    }
  }
}
