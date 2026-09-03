import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// Nearby networks, one key to join or leave, and a password prompt for one
// that has not been seen before. Anything past that -- static addresses, a
// VPN, per-connection settings -- hands over to nm-connection-editor.
//
// Summoned by the host:
//   zenix-shell shell toggle zenix.wifi
Item {
  id: root

  property bool opened: false

  function open(payload) {
    filter = ""
    filtering = false
    cancelPassword()
    opened = true
    wifi.refresh()
  }

  function close() {
    opened = false
  }

  WifiService {
    id: wifi
    active: root.opened
  }

  property string filter: ""
  property bool filtering: false

  // Set while a password is being typed for a network that is not saved.
  property string passwordFor: ""
  property string password: ""

  // Selection follows the SSID, not the row number: the list re-sorts as
  // signal strengths move, and an index would slide onto another network
  // underneath the key about to act on it.
  property string selectedSsid: ""

  readonly property var rows: {
    var needle = filter.toLowerCase()
    if (needle.length === 0) return wifi.networks
    var out = []
    for (var i = 0; i < wifi.networks.length; i++) {
      if (wifi.networks[i].ssid.toLowerCase().indexOf(needle) !== -1) out.push(wifi.networks[i])
    }
    return out
  }

  readonly property int selectedIndex: {
    for (var i = 0; i < rows.length; i++) if (rows[i].ssid === selectedSsid) return i
    return rows.length > 0 ? 0 : -1
  }

  readonly property var selectedRow: selectedIndex >= 0 ? rows[selectedIndex] : null

  function move(delta) {
    if (rows.length === 0) return
    var next = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    selectedSsid = rows[next].ssid
  }

  function cancelPassword() {
    passwordFor = ""
    password = ""
  }

  // The one key worth having: whatever this network is doing, do the opposite.
  // A secured network nobody has joined before is the only case that needs
  // anything more, and that is the prompt.
  function activate(network) {
    if (!network || wifi.isBusy(network.ssid)) return

    if (network.active) {
      wifi.disconnect(network.ssid)
      return
    }
    if (network.known || !network.secured) {
      wifi.connect(network.ssid, "")
      return
    }
    passwordFor = network.ssid
    password = ""
  }

  function submitPassword() {
    if (password.length === 0) return
    wifi.connect(passwordFor, password)
    cancelPassword()
  }

  function handleKey(event) {
    var control = (event.modifiers & Qt.ControlModifier) !== 0

    // Typing a password takes every key: a passphrase can contain j, k, /, and
    // anything else that would otherwise be a shortcut.
    if (passwordFor.length > 0) {
      event.accepted = true
      if (event.key === Qt.Key_Escape) {
        cancelPassword()
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        submitPassword()
      } else if (event.key === Qt.Key_Backspace) {
        if (password.length > 0) password = password.substring(0, password.length - 1)
        else cancelPassword()
      } else if (event.text.length === 1 && event.text >= " ") {
        password += event.text
      }
      return
    }

    if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_J)) {
      move(1); event.accepted = true; return
    }
    if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_K)) {
      move(-1); event.accepted = true; return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activate(selectedRow); event.accepted = true; return
    }

    if (filtering) {
      if (event.key === Qt.Key_Escape) {
        filtering = false; filter = ""; event.accepted = true; return
      }
      if (event.key === Qt.Key_Backspace) {
        if (filter.length > 0) filter = filter.substring(0, filter.length - 1)
        else filtering = false
        event.accepted = true
        return
      }
      if (event.text.length === 1 && event.text >= " ") {
        filter += event.text
        event.accepted = true
      }
      return
    }

    switch (event.key) {
    case Qt.Key_Slash: filtering = true; event.accepted = true; break
    case Qt.Key_J: move(1); event.accepted = true; break
    case Qt.Key_K: move(-1); event.accepted = true; break
    case Qt.Key_S: wifi.rescan(); event.accepted = true; break
    case Qt.Key_P: wifi.setRadio(!wifi.radioEnabled); event.accepted = true; break
    case Qt.Key_E: wifi.openEditor(); root.close(); event.accepted = true; break
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-wifi"
    cardWidth: 620
    cardHeight: 480

    onDismissed: root.close()
    onKeyPressed: function (event) { root.handleKey(event) }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // --- header ---------------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.bottomMargin: Style.gap
        spacing: Style.gap

        Text {
          text: "Wi-Fi"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Text {
          text: {
            if (wifi.lastActionError.length > 0) return wifi.lastActionError
            if (wifi.error.length > 0) return ""
            if (!wifi.ready) return "checking…"
            if (!wifi.radioEnabled) return "wi-fi is off"
            if (wifi.scanning) return "scanning…"
            if (wifi.activeNetwork) return "on " + wifi.activeNetwork.ssid
            return wifi.networks.length + " networks"
          }
          color: wifi.lastActionError.length > 0 ? Color.red : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          elide: Text.ElideRight
          Layout.maximumWidth: 320
        }
      }

      // --- password -------------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.pad
        Layout.rightMargin: Style.pad
        Layout.bottomMargin: Style.gap
        spacing: Style.gap
        visible: root.passwordFor.length > 0

        Text {
          text: ""
          color: Color.accent
          font.family: Style.font.mono
          font.pixelSize: Style.font.body
        }

        Text {
          text: "Password for " + root.passwordFor
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
        }

        Text {
          // Dots, not the passphrase: this popup sits over the desktop.
          text: "•".repeat(root.password.length)
          color: Color.foreground
          font.family: Style.font.mono
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: "⏎ join   esc cancel"
          color: Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.small
        }
      }

      // --- filter ---------------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.pad
        Layout.rightMargin: Style.pad
        Layout.bottomMargin: Style.gap
        spacing: Style.gap
        visible: root.filtering

        Text {
          text: "/"
          color: Color.accent
          font.family: Style.font.mono
          font.pixelSize: Style.font.body
        }

        Text {
          text: root.filter.length > 0 ? root.filter : "filter by name"
          color: root.filter.length > 0 ? Color.foreground : Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: root.rows.length + " of " + wifi.networks.length
          color: Color.faint
          font.family: Style.font.mono
          font.pixelSize: Style.font.small
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      // --- list -----------------------------------------------------------

      ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.gap
        clip: true
        spacing: 2

        model: root.rows
        currentIndex: root.selectedIndex
        highlightMoveDuration: Style.fast
        boundsBehavior: Flickable.StopAtBounds

        delegate: NetworkRow {
          required property var modelData

          width: list.width
          network: modelData
          selected: modelData.ssid === root.selectedSsid
            || (root.selectedSsid === "" && root.selectedIndex >= 0
                && root.rows[root.selectedIndex].ssid === modelData.ssid)
          busy: wifi.isBusy(modelData.ssid)

          onActivated: {
            root.selectedSsid = modelData.ssid
            root.activate(modelData)
          }
        }
      }

      Text {
        visible: root.rows.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.pad
        text: {
          if (!wifi.ready) return "Checking…"
          if (wifi.error.length > 0) return wifi.error
          if (!wifi.radioEnabled) return "Wi-Fi is off.  p turns it on."
          if (root.filter.length > 0) return "Nothing matches “" + root.filter + "”."
          return "No networks in range.  s scans again."
        }
        color: wifi.error.length > 0 ? Color.red : Color.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      // --- footer ----------------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.topMargin: Style.gap
        Layout.bottomMargin: Style.gap
        spacing: Style.gapWide

        KeyHint {
          key: "⏎"
          label: root.selectedRow && root.selectedRow.active ? "disconnect" : "connect"
        }
        KeyHint { key: "s"; label: "scan" }
        KeyHint { key: "p"; label: wifi.radioEnabled ? "wi-fi off" : "wi-fi on" }
        KeyHint { key: "e"; label: "editor" }

        Item { Layout.fillWidth: true }

        KeyHint { key: "/"; label: "filter" }
      }
    }
  }
}
