import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.Commons

// A centred popup card on a dimmed fullscreen layer, with click-outside and
// Escape to dismiss. Every summoned plugin in this shell is one of these, so
// the layer-shell details, the scrim and the open/close animation live here
// once rather than in each plugin.
//
// Consumers put their content inside and handle keys via onKeyPressed:
//
//   Overlay {
//     opened: root.opened
//     onDismissed: root.close()
//     onKeyPressed: event => { ... }
//     Text { ... }
//   }
Item {
  id: root

  property bool opened: false

  // Shows up in `hyprctl layers` and is what the layer rule in hyprland.lua
  // matches to blur what is behind the card.
  property string layerNamespace: "zenix-overlay"

  property int cardWidth: 720
  property int cardHeight: 480

  signal dismissed()
  signal keyPressed(var event)

  default property alias content: body.data

  // The window has to outlive `opened` or the card would vanish instead of
  // fading out. It is torn down once the fade has had time to finish.
  property bool closing: false

  onOpenedChanged: {
    if (opened) {
      closing = false
      closeTimer.stop()
      body.forceActiveFocus()
    } else {
      closing = true
      closeTimer.restart()
    }
  }

  Timer {
    id: closeTimer
    interval: Style.fast
    onTriggered: root.closing = false
  }

  PanelWindow {
    id: window

    visible: root.opened || root.closing

    // Fullscreen so the scrim covers the desktop and a click anywhere outside
    // the card can dismiss it.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, not OnDemand: the popup is a modal moment and typing into it
    // should never reach the window underneath.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Covering the whole screen would otherwise be read as a request to
    // reserve the whole screen, and every tiled window would collapse.
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.scrim
      opacity: root.opened ? 1 : 0
      Behavior on opacity {
        NumberAnimation { duration: Style.fast; easing.type: Easing.OutQuad }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
      }
    }

    Rectangle {
      id: card

      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent

      color: Color.background
      radius: Style.radius
      border.width: Style.border
      border.color: Color.border
      clip: true

      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.97

      Behavior on opacity {
        NumberAnimation { duration: Style.fast; easing.type: Easing.OutQuad }
      }
      Behavior on scale {
        NumberAnimation { duration: Style.normal; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
      }

      // Swallows clicks that land on the card so they do not reach the
      // dismissing MouseArea underneath.
      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: body
        anchors.fill: parent

        // Keys are caught here rather than on the window so that focus is
        // restored on every reopen, not just the first one.
        focus: true
        Keys.priority: Keys.BeforeItem
        // Content gets first refusal on every key, Escape included: a popup
        // with a filter open wants Escape to clear the filter rather than
        // close the window. Only an Escape nobody claimed dismisses.
        Keys.onPressed: function(event) {
          root.keyPressed(event)
          if (event.accepted) return

          if (event.key === Qt.Key_Escape) {
            root.dismissed()
            event.accepted = true
          }
        }
      }
    }

    // A window that is mapped but not focused would eat the keybind that
    // opened it, so focus is taken back every time the card appears.
    onVisibleChanged: if (visible) body.forceActiveFocus()
  }
}
