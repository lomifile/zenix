import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// Paired devices, and one key to connect or disconnect. Anything beyond that
// -- pairing something new, renaming, per-profile settings -- hands over to
// blueman, the same way the containers popup hands over to lazydocker.
//
// Summoned by the host:
//   zenix-shell shell toggle zenix.bluetooth
Item {
  id: root

  property bool opened: false

  function open(payload) {
    // Reopening should feel like a fresh look, not like returning to whatever
    // was typed into it last time.
    filter = ""
    filtering = false
    opened = true
    bt.refresh()
  }

  function close() {
    opened = false
  }

  BluetoothService {
    id: bt
    active: root.opened
  }

  property string filter: ""
  property bool filtering: false

  // Selection is tracked by MAC rather than row number: the list re-sorts as
  // devices connect and drop, and an index would slide onto a different
  // device underneath the key about to act on it.
  property string selectedMac: ""

  readonly property var rows: {
    var needle = filter.toLowerCase()
    if (needle.length === 0) return bt.devices

    var out = []
    for (var i = 0; i < bt.devices.length; i++) {
      var row = bt.devices[i]
      if (row.name.toLowerCase().indexOf(needle) !== -1
        || row.mac.toLowerCase().indexOf(needle) !== -1) out.push(row)
    }
    return out
  }

  readonly property int selectedIndex: {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].mac === selectedMac) return i
    }
    return rows.length > 0 ? 0 : -1
  }

  readonly property var selectedRow: selectedIndex >= 0 ? rows[selectedIndex] : null

  function move(delta) {
    if (rows.length === 0) return
    var next = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    selectedMac = rows[next].mac
  }

  function handleKey(event) {
    var control = (event.modifiers & Qt.ControlModifier) !== 0

    if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_J)) {
      move(1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_K)) {
      move(-1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      bt.toggle(selectedRow)
      event.accepted = true
      return
    }

    // While filtering, letters are text. Arrows and Ctrl-J/K above still move,
    // which is why they are handled before this point.
    if (filtering) {
      if (event.key === Qt.Key_Escape) {
        filtering = false
        filter = ""
        event.accepted = true
        return
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
    case Qt.Key_Slash:
      filtering = true
      event.accepted = true
      break
    case Qt.Key_J:
      move(1)
      event.accepted = true
      break
    case Qt.Key_K:
      move(-1)
      event.accepted = true
      break
    case Qt.Key_T:
      if (selectedRow) {
        bt.run(selectedRow.trusted ? "untrust" : "trust", selectedRow.mac, selectedRow.name)
      }
      event.accepted = true
      break
    case Qt.Key_S:
      bt.scan()
      event.accepted = true
      break
    case Qt.Key_P:
      bt.setPower(!bt.adapterPowered)
      event.accepted = true
      break
    case Qt.Key_B:
      bt.openManager()
      root.close()
      event.accepted = true
      break
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-bluetooth"
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
          text: "Bluetooth"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Text {
          // Either what went wrong with the last action or how the adapter is
          // doing. The error wins: it is the newer news.
          text: {
            if (bt.lastActionError.length > 0) return bt.lastActionError
            if (bt.error.length > 0) return ""
            if (!bt.ready) return "checking…"
            if (!bt.adapterPowered) return "adapter off"
            if (bt.scanning) return "scanning…"
            return bt.connectedCount + " connected · " + bt.devices.length + " known"
          }
          color: bt.lastActionError.length > 0 ? Color.red : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          elide: Text.ElideRight
          Layout.maximumWidth: 320
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
          text: root.filter.length > 0 ? root.filter : "filter by name or address"
          color: root.filter.length > 0 ? Color.foreground : Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: root.rows.length + " of " + bt.devices.length
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

        delegate: DeviceRow {
          required property var modelData

          width: list.width
          device: modelData
          selected: modelData.mac === root.selectedMac
            || (root.selectedMac === "" && root.selectedIndex >= 0
                && root.rows[root.selectedIndex].mac === modelData.mac)
          busy: bt.isBusy(modelData.mac)

          onActivated: {
            root.selectedMac = modelData.mac
            bt.toggle(modelData)
          }
        }
      }

      // Why the list is empty: an adapter that is off, a daemon that is not
      // answering and simply nothing paired are three different problems.
      Text {
        visible: root.rows.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.pad
        text: {
          if (!bt.ready) return "Checking…"
          if (bt.error.length > 0) return bt.error
          if (!bt.adapterPowered) return "Bluetooth is off.  p turns it on."
          if (root.filter.length > 0) return "Nothing matches “" + root.filter + "”."
          return "No devices yet.  s scans for nearby ones."
        }
        color: bt.error.length > 0 ? Color.red : Color.faint
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
          label: root.selectedRow && root.selectedRow.connected ? "disconnect" : "connect"
        }
        KeyHint {
          key: "t"
          label: root.selectedRow && root.selectedRow.trusted ? "untrust" : "trust"
        }
        KeyHint { key: "s"; label: "scan" }
        KeyHint { key: "p"; label: bt.adapterPowered ? "power off" : "power on" }
        KeyHint { key: "b"; label: "blueman" }

        Item { Layout.fillWidth: true }

        KeyHint { key: "/"; label: "filter" }
      }
    }
  }
}
