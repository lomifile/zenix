import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Ui

// The month and today's agenda, side by side.
//
// The agenda comes from the cache the bar already reads, so this popup adds no
// dependency of its own and cannot disagree with the clock beside it. Opening
// it is a file read.
//
// Summoned by the host:
//   zenix-shell shell toggle zenix.calendar
// which is what clicking the clock in waybar runs.
Item {
  id: root

  property bool opened: false

  // One notion of "now" for the whole popup, refreshed on open so a shell
  // that has been up for days does not open on yesterday.
  property date today: new Date()
  property int monthOffset: 0

  function open(payload) {
    today = new Date()
    monthOffset = 0
    opened = true
  }

  function close() {
    opened = false
  }

  AgendaService {
    id: agenda
  }

  function handleKey(event) {
    switch (event.key) {
    case Qt.Key_Left:
    case Qt.Key_H:
      monthOffset -= 1
      event.accepted = true
      break
    case Qt.Key_Right:
    case Qt.Key_L:
      monthOffset += 1
      event.accepted = true
      break
    case Qt.Key_T:
      today = new Date()
      monthOffset = 0
      event.accepted = true
      break
    case Qt.Key_R:
      agenda.refresh()
      event.accepted = true
      break
    case Qt.Key_G:
      // Anything beyond looking belongs in the real calendar, so hand over
      // rather than reimplement it here.
      agenda.openWeb()
      root.close()
      event.accepted = true
      break
    case Qt.Key_Escape:
      // Escape returns to today before it closes, so a popup left on some
      // other month does not need two keys to put right.
      if (monthOffset !== 0) {
        monthOffset = 0
        event.accepted = true
      }
      break
    }
  }

  Overlay {
    opened: root.opened
    layerNamespace: "zenix-calendar"
    cardWidth: 660
    cardHeight: 420

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
          text: month.title
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Text {
          // Says why the list is empty, or how old it is. The error wins: it
          // is the reason there is nothing to show.
          text: {
            if (agenda.refreshing) return "refreshing…"
            if (!agenda.loaded) return ""
            if (agenda.error.length > 0) return agenda.error
            if (agenda.ageMinutes < 0) return ""
            if (agenda.ageMinutes < 1) return "just now"
            return "updated " + agenda.ageMinutes + " min ago"
          }
          color: agenda.error.length > 0 && !agenda.refreshing
            ? Color.red : Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          elide: Text.ElideRight
          Layout.maximumWidth: 300
        }
      }

      // --- month | agenda --------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.pad
        spacing: Style.pad

        MonthGrid {
          id: month
          today: root.today
          monthOffset: root.monthOffset
          Layout.alignment: Qt.AlignTop
        }

        Rectangle {
          Layout.fillHeight: true
          implicitWidth: 1
          color: Color.separator
        }

        // --- today's agenda ----------------------------------------------

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.gapTight

          Text {
            text: "Today"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
          }

          Text {
            text: root.today.toLocaleDateString(Qt.locale(), "dddd, dd MMMM")
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.small
            Layout.bottomMargin: Style.gap
          }

          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.gap
            boundsBehavior: Flickable.StopAtBounds

            model: agenda.error.length > 0 ? [] : agenda.events

            delegate: RowLayout {
              required property var modelData

              width: ListView.view.width
              spacing: Style.gap

              Rectangle {
                Layout.fillHeight: true
                Layout.minimumHeight: 28
                implicitWidth: 3
                radius: 2
                color: Color.accent
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                  text: modelData.time && modelData.time.length > 0
                    ? modelData.time : "All day"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.small
                }

                Text {
                  text: modelData.title
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
              }
            }
          }

          // The empty and error states share this line; the header already
          // says which of the two it is.
          Text {
            visible: agenda.loaded
              && (agenda.error.length > 0 || agenda.events.length === 0)
            text: agenda.error.length > 0
              ? "Nothing to show"
              : "No events today"
            color: Color.faint
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            Layout.fillWidth: true
            Layout.fillHeight: true
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Color.separator
      }

      // --- footer ----------------------------------------------------------

      RowLayout {
        Layout.fillWidth: true
        Layout.margins: Style.pad
        Layout.topMargin: Style.gap
        Layout.bottomMargin: Style.gap
        spacing: Style.gapWide

        KeyHint { key: "←→"; label: "month" }
        KeyHint { key: "t"; label: "today" }
        KeyHint { key: "r"; label: "refresh" }
        KeyHint { key: "g"; label: "google calendar" }

        Item { Layout.fillWidth: true }

        KeyHint { key: "esc"; label: "close" }
      }
    }
  }
}
