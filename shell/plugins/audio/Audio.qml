import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false

  function open(payload) {
    filter = ""
    filtering = false
    opened = true
    audio.refresh()
  }

  function close() {
    opened = false
  }

  AudioService {
    id: audio
    active: root.opened
  }

  property string filter: ""
  property bool filtering: false

  property string selectedKey: ""

  function keyOf(node) {
    return node.kind + "|" + node.name
  }

  function matches(node) {
    var needle = filter.toLowerCase()
    if (needle.length === 0) return true
    return node.description.toLowerCase().indexOf(needle) !== -1
      || node.name.toLowerCase().indexOf(needle) !== -1
  }

  readonly property var rows: {
    var out = []
    var outputs = audio.sinks.filter(matches)
    var inputs = audio.sources.filter(matches)

    out.push({ type: "header", label: "Output", trailing: outputs.length + (outputs.length === 1 ? " device" : " devices") })
    for (var i = 0; i < outputs.length; i++) out.push({ type: "node", node: outputs[i] })

    out.push({ type: "header", label: "Input", trailing: inputs.length + (inputs.length === 1 ? " device" : " devices") })
    for (var j = 0; j < inputs.length; j++) out.push({ type: "node", node: inputs[j] })

    return out
  }

  readonly property int nodeCount: audio.sinks.length + audio.sources.length

  readonly property int selectedIndex: {
    var firstNode = -1
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].type !== "node") continue
      if (firstNode < 0) firstNode = i
      if (keyOf(rows[i].node) === selectedKey) return i
    }
    return firstNode
  }

  readonly property var selectedNode: selectedIndex >= 0 && rows[selectedIndex].type === "node"
    ? rows[selectedIndex].node
    : null

  function move(delta) {
    if (selectedIndex < 0) return
    var i = selectedIndex + delta
    while (i >= 0 && i < rows.length && rows[i].type !== "node") i += delta
    if (i < 0 || i >= rows.length) return
    selectedKey = keyOf(rows[i].node)
  }

  function handleKey(event) {
    var control = (event.modifiers & Qt.ControlModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0
    var step = shift ? 1 : 5

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
    if (event.key === Qt.Key_Left) {
      audio.nudge(selectedNode, -step)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Right) {
      audio.nudge(selectedNode, step)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      audio.setDefault(selectedNode)
      event.accepted = true
      return
    }

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
    case Qt.Key_H:
      audio.nudge(selectedNode, -step)
      event.accepted = true
      break
    case Qt.Key_L:
      audio.nudge(selectedNode, step)
      event.accepted = true
      break
    case Qt.Key_M:
      audio.toggleMute(selectedNode)
      event.accepted = true
      break
    case Qt.Key_P:
      audio.openMixer()
      root.close()
      event.accepted = true
      break
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-audio"
    cardWidth: 660
    cardHeight: 560

    onDismissed: root.close()
    onKeyPressed: function (event) { root.handleKey(event) }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.bottomMargin: Style.gap
        spacing: Style.gap

        Text {
          text: "Sound"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Text {
          text: {
            if (audio.lastActionError.length > 0) return audio.lastActionError
            if (audio.error.length > 0) return ""
            if (!audio.ready) return "checking…"
            var sink = audio.defaultSinkNode
            if (!sink) return "no output"
            return sink.description + "  ·  "
              + (sink.mute ? "muted" : audio.volumeOf(sink) + "%")
          }
          color: audio.lastActionError.length > 0 ? Color.red : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          elide: Text.ElideRight
          Layout.maximumWidth: 360
        }
      }

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
          text: root.filter.length > 0 ? root.filter : "filter by device name"
          color: root.filter.length > 0 ? Color.foreground : Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.gap
        clip: true
        spacing: 2
        visible: root.nodeCount > 0

        model: root.rows
        currentIndex: root.selectedIndex
        highlightMoveDuration: Style.fast
        boundsBehavior: Flickable.StopAtBounds

        delegate: Loader {
          required property var modelData

          width: list.width
          sourceComponent: modelData.type === "header" ? headerComponent : nodeComponent

          Component {
            id: headerComponent

            SectionHeader {
              label: modelData.label
              trailing: modelData.trailing
            }
          }

          Component {
            id: nodeComponent

            DeviceRow {
              device: modelData.node
              selected: root.selectedIndex >= 0
                && root.rows[root.selectedIndex].type === "node"
                && root.keyOf(root.rows[root.selectedIndex].node) === root.keyOf(modelData.node)
              isDefault: modelData.node.kind === "sink"
                ? audio.defaultSink === modelData.node.name
                : audio.defaultSource === modelData.node.name
              busy: audio.isBusy(modelData.node.name)
              volume: audio.volumeOf(modelData.node)

              onActivated: {
                root.selectedKey = root.keyOf(modelData.node)
                audio.setDefault(modelData.node)
              }
              onMuteToggled: {
                root.selectedKey = root.keyOf(modelData.node)
                audio.toggleMute(modelData.node)
              }
              onVolumeRequested: function (value) {
                root.selectedKey = root.keyOf(modelData.node)
                audio.setVolume(modelData.node, value)
              }
            }
          }
        }
      }

      Text {
        visible: root.nodeCount === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.pad
        text: {
          if (!audio.ready) return "Checking…"
          if (audio.error.length > 0) return audio.error
          return "No audio devices.  Is pipewire running?"
        }
        color: audio.error.length > 0 ? Color.red : Color.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

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

        KeyHint { key: "⏎"; label: "make default" }
        KeyHint { key: "←→"; label: "volume" }
        KeyHint { key: "m"; label: root.selectedNode && root.selectedNode.mute ? "unmute" : "mute" }
        KeyHint { key: "p"; label: "pavucontrol" }

        Item { Layout.fillWidth: true }

        KeyHint { key: "/"; label: "filter" }
      }
    }
  }
}
