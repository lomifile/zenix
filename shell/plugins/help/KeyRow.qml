import QtQuick
import QtQuick.Layouts

import qs.Commons

Item {
  id: root

  required property string keys
  required property string label
  property int keyColumn: 132

  readonly property var chips: keys.split("+").map(function(part) { return part.trim() })

  implicitHeight: 24

  RowLayout {
    anchors.fill: parent
    spacing: Style.gap

    Item {
      Layout.preferredWidth: root.keyColumn
      Layout.fillHeight: true

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.gapTight

        Repeater {
          model: root.chips

          Rectangle {
            required property string modelData

            width: Math.max(18, chip.implicitWidth + Style.gap)
            height: 17
            radius: 4
            color: Color.elevated
            border.width: Style.border
            border.color: Color.separator

            Text {
              id: chip
              anchors.centerIn: parent
              text: parent.modelData
              color: Color.foreground
              font.family: Style.font.mono
              font.pixelSize: Style.font.small
            }
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.label
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }
}
