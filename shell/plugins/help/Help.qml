import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property string filter: ""
  property bool filtering: false

  function open(payload) {
    filter = ""
    filtering = false
    flick.contentY = 0
    opened = true
  }

  function close() {
    opened = false
  }

  Keybindings { id: binds }

  readonly property var groups: {
    var needle = filter.toLowerCase()
    if (needle.length === 0) return binds.groups

    var out = []
    for (var i = 0; i < binds.groups.length; i++) {
      var group = binds.groups[i]
      var kept = []
      for (var j = 0; j < group.items.length; j++) {
        var item = group.items[j]
        if (item.label.toLowerCase().indexOf(needle) !== -1
          || item.keys.toLowerCase().indexOf(needle) !== -1
          || group.title.toLowerCase().indexOf(needle) !== -1) kept.push(item)
      }
      if (kept.length > 0) out.push({ title: group.title, items: kept })
    }
    return out
  }

  readonly property int total: {
    var n = 0
    for (var i = 0; i < groups.length; i++) n += groups[i].items.length
    return n
  }

  readonly property var columns: {
    var left = []
    var right = []
    var leftRows = 0
    var rightRows = 0
    for (var i = 0; i < groups.length; i++) {
      var rows = groups[i].items.length + 2
      if (leftRows <= rightRows) {
        left.push(groups[i])
        leftRows += rows
      } else {
        right.push(groups[i])
        rightRows += rows
      }
    }
    return [left, right]
  }

  function scroll(delta) {
    var limit = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(limit, flick.contentY + delta))
  }

  function handleKey(event) {
    var control = (event.modifiers & Qt.ControlModifier) !== 0

    if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_J)) {
      scroll(48)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_K)) {
      scroll(-48)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageDown) {
      scroll(flick.height * 0.9)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageUp) {
      scroll(-flick.height * 0.9)
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
        flick.contentY = 0
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
      scroll(48)
      event.accepted = true
      break
    case Qt.Key_K:
      scroll(-48)
      event.accepted = true
      break
    case Qt.Key_G:
      scroll((event.modifiers & Qt.ShiftModifier) ? flick.contentHeight : -flick.contentHeight)
      event.accepted = true
      break
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-help"
    cardWidth: 1040
    cardHeight: 640

    onDismissed: root.close()
    onKeyPressed: function(event) { root.handleKey(event) }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.bottomMargin: Style.gap
        spacing: Style.gap

        Text {
          text: "Keybindings"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Text {
          text: root.filtering
            ? root.total + (root.total === 1 ? " match" : " matches")
            : "SUPER unless a key says otherwise"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
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
          text: root.filter.length > 0 ? root.filter : "filter by key or action"
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

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.pad

        Text {
          anchors.centerIn: parent
          visible: root.groups.length === 0
          text: "Nothing matches “" + root.filter + "”"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Flickable {
          id: flick

          anchors.fill: parent
          clip: true
          contentHeight: sheet.height
          boundsBehavior: Flickable.StopAtBounds

          Behavior on contentY {
            NumberAnimation { duration: Style.fast; easing.type: Easing.OutQuad }
          }

          Row {
            id: sheet

            width: flick.width
            spacing: Style.pad * 2

            Repeater {
              model: root.columns

              Column {
                id: column

                required property var modelData

                width: (sheet.width - sheet.spacing) / 2
                spacing: Style.gapWide

                Repeater {
                  model: column.modelData

                  GroupSection {
                    required property var modelData

                    width: column.width
                    title: modelData.title
                    items: modelData.items
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.topMargin: Style.gapWide
        Layout.bottomMargin: Style.gapWide
        spacing: Style.gapWide

        KeyHint { key: "j"; label: "down" }
        KeyHint { key: "k"; label: "up" }
        KeyHint { key: "G"; label: "end" }
        KeyHint { key: "esc"; label: "close" }

        Item { Layout.fillWidth: true }

        Text {
          text: root.total + " binds"
          color: Color.faint
          font.family: Style.font.mono
          font.pixelSize: Style.font.small
        }

        KeyHint { key: "/"; label: "filter" }
      }
    }
  }
}
