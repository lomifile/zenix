import QtQuick
import QtQuick.Layouts

import qs.Commons

ColumnLayout {
  id: root

  required property string title
  required property var items
  property int keyColumn: 132

  spacing: Style.gapTight

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: 2
    spacing: Style.gap

    Text {
      text: root.title
      color: Color.faint
      font.family: Style.font.family
      font.pixelSize: Style.font.small
      font.weight: Font.DemiBold
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.6
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      color: Color.separator
    }
  }

  Repeater {
    model: root.items

    KeyRow {
      required property var modelData

      Layout.fillWidth: true
      keys: modelData.keys
      label: modelData.label
      keyColumn: root.keyColumn
    }
  }
}
