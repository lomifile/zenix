import QtQuick
import QtQuick.Layouts

import qs.Commons

RowLayout {
  id: segment

  required property var group
  required property bool leading

  signal tabActivated(string address)
  signal tabClosed(string address)

  spacing: Style.gap

  Rectangle {
    visible: !segment.leading
    implicitWidth: 1
    Layout.preferredHeight: 16
    Layout.alignment: Qt.AlignVCenter
    color: Color.separator
  }

  Repeater {
    model: segment.group.tabs

    delegate: Tab {
      required property var modelData

      model: modelData
      dimmed: !segment.group.focused

      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignVCenter

      onActivated: segment.tabActivated(modelData.address)
      onClosed: segment.tabClosed(modelData.address)
    }
  }
}
