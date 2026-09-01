import QtQuick

import qs.Commons

// One "key — what it does" pair in a popup's footer. The key is boxed so a
// glance can pick the shortcuts out of the row without reading the labels.
Row {
  id: root

  property string key: ""
  property string label: ""

  spacing: Style.gapTight

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    // Wide enough for the widest chord the popup shows, so the boxes line up
    // rather than each hugging its own glyph.
    width: Math.max(18, keyText.implicitWidth + Style.gap)
    height: 16
    radius: 4
    color: Color.elevated

    Text {
      id: keyText
      anchors.centerIn: parent
      text: root.key
      color: Color.muted
      font.family: Style.font.mono
      font.pixelSize: Style.font.small
    }
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Color.faint
    font.family: Style.font.family
    font.pixelSize: Style.font.small
  }
}
