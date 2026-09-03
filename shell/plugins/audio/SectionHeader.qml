import QtQuick
import QtQuick.Layouts

import qs.Commons

Item {
  id: root

  required property string label
  required property string trailing

  implicitHeight: 26

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.gapWide
    anchors.rightMargin: Style.gapWide
    spacing: Style.gap

    Text {
      text: root.label
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

    Text {
      text: root.trailing
      color: Color.faint
      font.family: Style.font.family
      font.pixelSize: Style.font.small
    }
  }
}
