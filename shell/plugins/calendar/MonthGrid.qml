import QtQuick

import qs.Commons

// One month, drawn as a grid of days.
//
// Monday-first, with the days either side of the month shown faintly so the
// weeks stay whole, and today as a filled disc -- the treatment Calendar.app
// uses. Deliberately not interactive: this is a glance, and every key in the
// popup belongs to the agenda beside it.
Item {
  id: root

  // Injected rather than read from the clock here, so the popup can hold one
  // notion of "now" across the grid and the agenda header.
  property date today: new Date()

  // 0 is the month containing `today`; the arrow keys walk this.
  property int monthOffset: 0

  readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
  readonly property string title: shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")

  readonly property int cell: 32

  implicitWidth: cell * 7
  implicitHeight: header.height + Style.gap + grid.height

  // Monday-first: JS weekdays start on Sunday, so Sunday has to wrap to the end.
  readonly property int leading: (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7

  readonly property var days: {
    var out = []
    var first = new Date(shown.getFullYear(), shown.getMonth(), 1)
    // Six rows always: a month can straddle six weeks, and a grid that changes
    // height as the arrows walk through the year is worse than a blank row.
    for (var i = 0; i < 42; i++) {
      var d = new Date(first.getFullYear(), first.getMonth(), 1 - leading + i)
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === shown.getMonth(),
        isToday: d.getFullYear() === today.getFullYear()
          && d.getMonth() === today.getMonth()
          && d.getDate() === today.getDate()
      })
    }
    return out
  }

  Row {
    id: header
    width: parent.width

    Repeater {
      model: 7
      delegate: Item {
        required property int index
        width: root.cell
        height: 20

        Text {
          anchors.centerIn: parent
          // Locale's own short day names, sliced to an initial so the row
          // stays as narrow as the grid under it.
          text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat)
            .charAt(0).toUpperCase()
          color: Color.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.small
          font.weight: Font.DemiBold
        }
      }
    }
  }

  Grid {
    id: grid

    anchors.top: header.bottom
    anchors.topMargin: Style.gap
    columns: 7

    Repeater {
      model: root.days

      delegate: Item {
        required property var modelData

        width: root.cell
        height: root.cell

        Rectangle {
          anchors.centerIn: parent
          width: root.cell - 4
          height: root.cell - 4
          radius: width / 2
          color: modelData.isToday ? Color.red : "transparent"
        }

        Text {
          anchors.centerIn: parent
          text: modelData.day
          color: modelData.isToday
            ? Color.foreground
            : (modelData.inMonth ? Color.foreground : Color.faint)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.weight: modelData.isToday ? Font.DemiBold : Font.Normal
        }
      }
    }
  }
}
