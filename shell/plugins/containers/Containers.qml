import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// The container monitor: what is running, what it is costing, and the four
// things worth doing about it without opening a terminal. Anything deeper --
// reading logs properly, poking around inside, watching a build -- hands off
// to a terminal, and `d` hands the whole question to lazydocker.
//
// Summoned by the host:
//   zenix-shell shell toggle zenix.containers
Item {
  id: root

  property bool opened: false

  function open(payload) {
    // Reopening should feel like a fresh look, not like returning to whatever
    // was typed into it last time.
    filter = ""
    filtering = false
    opened = true
    docker.refresh()
    docker.refreshStats()
  }

  function close() {
    opened = false
  }

  DockerService {
    id: docker
    active: root.opened
  }

  property string filter: ""
  property bool filtering: false

  // Selection is tracked by container id rather than by row number: the list
  // re-sorts itself every couple of seconds as containers start and stop, and
  // an index would quietly slide onto a different container underneath the
  // keys about to act on it.
  property string selectedId: ""

  readonly property var rows: {
    var needle = filter.toLowerCase()
    if (needle.length === 0) return docker.containers

    var out = []
    for (var i = 0; i < docker.containers.length; i++) {
      var row = docker.containers[i]
      if (row.name.toLowerCase().indexOf(needle) !== -1
        || row.image.toLowerCase().indexOf(needle) !== -1) out.push(row)
    }
    return out
  }

  readonly property int selectedIndex: {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].id === selectedId) return i
    }
    return rows.length > 0 ? 0 : -1
  }

  readonly property var selectedRow: selectedIndex >= 0 ? rows[selectedIndex] : null

  function move(delta) {
    if (rows.length === 0) return
    var next = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    selectedId = rows[next].id
  }

  // Enter is deliberately the one destructive-ish key, and it is the obvious
  // one: whatever this container is doing, do the opposite.
  function toggleSelected() {
    var row = selectedRow
    if (!row || docker.isBusy(row.id)) return
    docker.run(row.state === "running" ? "stop" : "start", row.id, row.name)
  }

  function actOnSelected(verb) {
    var row = selectedRow
    if (!row || docker.isBusy(row.id)) return
    docker.run(verb, row.id, row.name)
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
      toggleSelected()
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
    case Qt.Key_R:
      actOnSelected("restart")
      event.accepted = true
      break
    case Qt.Key_L:
      if (selectedRow) docker.openLogs(selectedRow.id, selectedRow.name)
      event.accepted = true
      break
    case Qt.Key_S:
      // A shell into a stopped container would only produce an error dialog
      // in a terminal that then closes.
      if (selectedRow && selectedRow.state === "running") docker.openShell(selectedRow.id, selectedRow.name)
      event.accepted = true
      break
    case Qt.Key_D:
      docker.openLazydocker()
      root.close()
      event.accepted = true
      break
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-containers"
    cardWidth: 760
    cardHeight: 520

    onDismissed: root.close()
    onKeyPressed: function(event) { root.handleKey(event) }

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
          text: "Containers"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Text {
          // One line that says either what went wrong with the last action or
          // how the host is doing. The error wins: it is the newer news.
          text: {
            if (docker.lastActionError.length > 0) return docker.lastActionError
            if (docker.error.length > 0) return ""
            if (!docker.ready) return "checking…"
            return docker.runningCount + " running · " + docker.stoppedCount + " stopped"
          }
          color: docker.lastActionError.length > 0 ? Color.red : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          elide: Text.ElideRight
          Layout.maximumWidth: 420
        }
      }

      // --- filter ---------------------------------------------------------

      // Only present while filtering. A permanently visible search box would
      // claim the keyboard and cost every other key a modifier.
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
          text: root.filter.length > 0 ? root.filter : "filter by name or image"
          color: root.filter.length > 0 ? Color.foreground : Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: root.rows.length + " of " + docker.containers.length
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
        // Keeps the selected row on screen as j/k walk past the fold.
        highlightMoveDuration: Style.fast
        boundsBehavior: Flickable.StopAtBounds

        delegate: ContainerRow {
          required property var modelData

          width: list.width
          container: modelData
          selected: modelData.id === root.selectedId
            || (root.selectedId === "" && root.selectedIndex >= 0 && root.rows[root.selectedIndex].id === modelData.id)
          busy: docker.isBusy(modelData.id)

          onActivated: {
            root.selectedId = modelData.id
            root.toggleSelected()
          }
        }

        // One message covering every reason the list is empty, because they
        // need very different responses from the person reading it.
        Item {
          anchors.fill: parent
          visible: root.rows.length === 0

          ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Style.pad * 4
            spacing: Style.gapTight

            Text {
              text: {
                if (docker.error.length > 0) return "Docker is not answering"
                if (!docker.ready) return "Checking Docker…"
                if (root.filter.length > 0) return "Nothing matches “" + root.filter + "”"
                return "No containers"
              }
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
            }

            Text {
              text: docker.error.length > 0
                ? docker.error
                : (docker.ready && root.filter.length === 0 && docker.containers.length === 0
                  ? "docker ps came back empty"
                  : "")
              visible: text.length > 0
              color: Color.faint
              font.family: Style.font.mono
              font.pixelSize: Style.font.small
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      // --- footer ---------------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.topMargin: Style.gapWide
        Layout.bottomMargin: Style.gapWide
        spacing: Style.gapWide

        KeyHint {
          key: "⏎"
          label: root.selectedRow && root.selectedRow.state === "running" ? "stop" : "start"
        }
        KeyHint { key: "r"; label: "restart" }
        KeyHint { key: "l"; label: "logs" }
        KeyHint { key: "s"; label: "shell" }
        KeyHint { key: "d"; label: "lazydocker" }

        Item { Layout.fillWidth: true }

        KeyHint { key: "/"; label: "filter" }
      }
    }
  }
}
