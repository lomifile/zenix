import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import qs.Commons

Item {
  id: root

  property bool opened: false

  readonly property int cardWidth: 380
  readonly property int gutter: 12

  function open(payload) {
    opened = true
  }

  function close() {
    opened = false
  }

  NotificationService {
    id: feed
  }

  Variants {
    model: Quickshell.screens

    delegate: Scope {
      id: scope

      required property var modelData

      readonly property var monitor: Hyprland.monitorFor(scope.modelData)
      readonly property bool onThisScreen: {
        var focused = Hyprland.focusedMonitor
        if (!focused || !monitor) return Quickshell.screens[0] === scope.modelData
        return focused.name === monitor.name
      }

      readonly property bool present: root.opened && onThisScreen && feed.list.length > 0

      PanelWindow {
        screen: scope.modelData
        visible: scope.present

        anchors { top: true; right: true }
        color: "transparent"

        WlrLayershell.namespace: "zenix-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        implicitWidth: root.cardWidth + root.gutter * 2
        implicitHeight: Math.max(1, stack.implicitHeight + root.gutter * 2)

        Column {
          id: stack

          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: root.gutter
          anchors.rightMargin: root.gutter

          width: root.cardWidth
          spacing: 10

          Repeater {
            model: feed.list

            delegate: NotificationCard {
              required property var modelData

              width: stack.width
              notification: modelData
              service: feed
            }
          }
        }
      }
    }
  }
}
