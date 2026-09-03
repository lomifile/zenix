import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
  id: service

  property var arrivals: ({})
  property int clock: 0

  readonly property var list: server.trackedNotifications
    ? server.trackedNotifications.values
    : []

  readonly property int defaultTimeout: 5000

  function timeoutFor(notification) {
    if (notification.urgency === NotificationUrgency.Critical) return 0
    if (notification.expireTimeout > 0) return notification.expireTimeout
    return defaultTimeout
  }

  function relativeTime(notification) {
    clock

    var at = arrivals[notification.id]
    if (!at) return "now"

    var seconds = Math.floor((Date.now() - at) / 1000)
    if (seconds < 45) return "now"

    var minutes = Math.round(seconds / 60)
    if (minutes < 60) return minutes + "m ago"

    return Math.round(minutes / 60) + "h ago"
  }

  function iconFor(notification) {
    if (notification.image && notification.image.length > 0) return notification.image

    var names = [notification.appIcon, notification.desktopEntry, notification.appName]
    for (var i = 0; i < names.length; i++) {
      var name = names[i]
      if (!name || name.length === 0) continue
      if (name.indexOf("/") === 0 || name.indexOf("file://") === 0) return name

      var resolved = Quickshell.iconPath(name, true)
      if (resolved && resolved.length > 0) return resolved
    }

    return ""
  }

  function label(notification) {
    if (notification.appName && notification.appName.length > 0) return notification.appName
    if (notification.desktopEntry && notification.desktopEntry.length > 0) return notification.desktopEntry
    return "Notification"
  }

  function defaultAction(notification) {
    var actions = notification.actions || []
    for (var i = 0; i < actions.length; i++) {
      if (actions[i].identifier === "default") return actions[i]
    }
    return null
  }

  function visibleActions(notification) {
    var out = []
    var actions = notification.actions || []
    for (var i = 0; i < actions.length; i++) {
      if (actions[i].identifier !== "default") out.push(actions[i])
    }
    return out
  }

  function activate(notification) {
    var action = defaultAction(notification)
    if (action) action.invoke()
    else notification.dismiss()
  }

  NotificationServer {
    id: server

    keepOnReload: false
    actionsSupported: true
    actionIconsSupported: false
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: function (notification) {
      notification.tracked = true
      service.arrivals[notification.id] = Date.now()
      service.clock += 1
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: service.list.length > 0
    onTriggered: service.clock += 1
  }
}
