// ComboBox restyled to match the greeter. The stock QtQuick.Controls Basic
// style renders a light grey widget, which looks wrong on a dark login screen.

import QtQuick
import QtQuick.Controls

ComboBox {
    id: control

    property color fg: "#f5f5f7"
    property color dim: "#98989d"
    property color accent: "#0a84ff"
    property string fontFamily: "Inter"

    implicitHeight: 30
    font.family: control.fontFamily
    font.pixelSize: 13

    background: Rectangle {
        radius: 7
        color: Qt.rgba(1, 1, 1, control.hovered ? 0.14 : 0.08)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    contentItem: Text {
        leftPadding: 10
        rightPadding: 24
        text: control.displayText
        color: control.fg
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 9
        y: (control.height - height) / 2
        text: "▾"
        color: control.dim
        font.pixelSize: 12
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
        padding: 4

        background: Rectangle {
            radius: 8
            color: "#2c2c2e"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }

    delegate: ItemDelegate {
        id: item
        required property var model
        required property int index

        width: control.width - 8
        height: 28
        highlighted: control.highlightedIndex === item.index

        background: Rectangle {
            radius: 6
            color: item.highlighted ? control.accent : "transparent"
        }

        contentItem: Text {
            leftPadding: 8
            text: item.model[control.textRole]
            color: control.fg
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
