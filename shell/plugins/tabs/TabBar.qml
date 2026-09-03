import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Commons

Item {
  id: root

  property bool opened: false

  readonly property int barHeight: 34
  readonly property int liftoff: 10

  function open(payload) {
    opened = true
  }

  function close() {
    opened = false
  }

  Variants {
    model: Quickshell.screens

    delegate: Scope {
      id: scope

      required property var modelData

      readonly property var groups: service.groups
      readonly property bool present: root.opened && groups.length > 0

      property bool closing: false

      onPresentChanged: {
        if (present) {
          closing = false
          closeTimer.stop()
        } else {
          closing = true
          closeTimer.restart()
        }
      }

      GroupService {
        id: service
        screen: scope.modelData
      }

      Timer {
        id: closeTimer
        interval: Style.normal
        onTriggered: scope.closing = false
      }

      PanelWindow {
        id: window

        screen: scope.modelData
        visible: scope.present || scope.closing

        anchors { bottom: true; left: true; right: true }
        color: "transparent"

        WlrLayershell.namespace: "zenix-tabs"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        implicitHeight: root.barHeight + root.liftoff * 2
        exclusiveZone: scope.present ? root.barHeight + root.liftoff : 0

        mask: Region {
          item: bar
        }

        Rectangle {
          id: bar

          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.liftoff

          width: strip.width + Style.gap * 2
          height: root.barHeight
          radius: height / 2

          color: Color.background
          border.width: Style.border
          border.color: Color.border

          opacity: scope.present ? 1 : 0
          scale: scope.present ? 1 : 0.96

          Behavior on opacity {
            NumberAnimation { duration: Style.fast; easing.type: Easing.OutQuad }
          }
          Behavior on scale {
            NumberAnimation { duration: Style.normal; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
          }
          Behavior on width {
            NumberAnimation { duration: Style.normal; easing.type: Easing.OutQuad }
          }

          RowLayout {
            id: strip

            anchors.centerIn: parent
            height: parent.height
            width: Math.min(implicitWidth, window.width - Style.pad * 2 - Style.gap * 2)
            spacing: Style.gap
            clip: true

            Repeater {
              model: scope.groups

              delegate: GroupSegment {
                required property var modelData
                required property int index

                group: modelData
                leading: index === 0

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                onTabActivated: function (address) { service.focus(address) }
                onTabClosed: function (address) { service.closeTab(address) }
              }
            }
          }
        }
      }
    }
  }
}
