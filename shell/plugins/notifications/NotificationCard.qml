import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import qs.Commons

Item {
  id: card

  required property var notification
  required property var service

  signal dismissed()

  readonly property string iconSource: service.iconFor(notification)
  readonly property var extraActions: service.visibleActions(notification)
  readonly property int timeout: service.timeoutFor(notification)

  property bool shown: false

  implicitHeight: surface.implicitHeight

  Component.onCompleted: shown = true

  Timer {
    interval: card.timeout
    running: card.timeout > 0 && !hover.hovered
    onTriggered: card.notification.expire()
  }

  Rectangle {
    id: surface

    width: parent.width
    implicitHeight: layout.implicitHeight + Style.pad * 2

    radius: 18
    color: Color.background
    border.width: Style.border
    border.color: Color.border

    opacity: card.shown ? 1 : 0
    scale: card.shown ? 1 : 0.94
    x: card.shown ? 0 : width * 0.25

    Behavior on opacity {
      NumberAnimation { duration: Style.normal; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
      NumberAnimation { duration: Style.normal; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
    }
    Behavior on x {
      NumberAnimation { duration: Style.normal; easing.type: Easing.OutCubic }
    }

    HoverHandler {
      id: hover
    }

    TapHandler {
      acceptedButtons: Qt.LeftButton
      onTapped: card.service.activate(card.notification)
    }

    TapHandler {
      acceptedButtons: Qt.RightButton | Qt.MiddleButton
      onTapped: card.notification.dismiss()
    }

    RowLayout {
      id: layout

      anchors.fill: parent
      anchors.margins: Style.pad
      spacing: Style.gapWide

      Rectangle {
        Layout.alignment: Qt.AlignTop
        implicitWidth: 38
        implicitHeight: 38
        radius: 9
        color: card.iconSource.length > 0 ? "transparent" : Color.elevated

        IconImage {
          anchors.fill: parent
          source: card.iconSource
          asynchronous: true
          visible: card.iconSource.length > 0
        }

        Text {
          anchors.centerIn: parent
          visible: card.iconSource.length === 0
          text: card.service.label(card.notification).charAt(0).toUpperCase()
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.gap

          Text {
            text: card.service.label(card.notification)
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.small
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: card.service.relativeTime(card.notification)
            color: Color.faint
            font.family: Style.font.family
            font.pixelSize: Style.font.small
          }
        }

        Text {
          visible: text.length > 0
          text: card.notification.summary
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          visible: text.length > 0
          text: card.notification.body
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          textFormat: Text.StyledText
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
          Layout.fillWidth: true
          onLinkActivated: function (link) { Qt.openUrlExternally(link) }
        }

        Flow {
          visible: card.extraActions.length > 0
          Layout.fillWidth: true
          Layout.topMargin: Style.gap
          spacing: Style.gap

          Repeater {
            model: card.extraActions

            delegate: Rectangle {
              required property var modelData

              implicitWidth: actionLabel.implicitWidth + Style.gapWide * 2
              implicitHeight: 24
              radius: 12
              color: actionHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Color.elevated

              Behavior on color {
                ColorAnimation { duration: Style.fast }
              }

              HoverHandler {
                id: actionHover
              }

              TapHandler {
                onTapped: modelData.invoke()
              }

              Text {
                id: actionLabel
                anchors.centerIn: parent
                text: modelData.text
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.small
              }
            }
          }
        }
      }
    }

    Rectangle {
      id: close

      anchors.horizontalCenter: parent.left
      anchors.verticalCenter: parent.top
      anchors.horizontalCenterOffset: 9
      anchors.verticalCenterOffset: 9

      width: 20
      height: 20
      radius: 10

      color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
      border.width: Style.border
      border.color: Color.border

      opacity: hover.hovered ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        NumberAnimation { duration: Style.fast }
      }
      Behavior on color {
        ColorAnimation { duration: Style.fast }
      }

      HoverHandler {
        id: closeHover
      }

      TapHandler {
        onTapped: card.notification.dismiss()
      }

      Text {
        anchors.centerIn: parent
        text: "✕"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 10
      }
    }
  }
}
