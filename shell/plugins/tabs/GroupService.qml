import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
  id: service

  required property var screen

  property int revision: 0

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  readonly property var workspace: monitor ? monitor.activeWorkspace : null

  function normalise(address) {
    return String(address || "").replace(/^0x/i, "").toLowerCase()
  }

  readonly property string focusedAddress: {
    revision

    var windows = workspace && workspace.toplevels ? workspace.toplevels.values : []
    for (var i = 0; i < windows.length; i++) {
      var ipc = windows[i].lastIpcObject
      if (ipc && ipc.focusHistoryID === 0) return normalise(windows[i].address)
    }

    var top = Hyprland.activeToplevel
    return top ? normalise(top.address) : ""
  }

  readonly property var groups: {
    revision

    if (!workspace || !workspace.toplevels) return []

    var windows = workspace.toplevels.values
    var byAddress = ({})
    for (var i = 0; i < windows.length; i++) {
      byAddress[normalise(windows[i].address)] = windows[i]
    }

    var seen = ({})
    var out = []

    for (var j = 0; j < windows.length; j++) {
      var ipc = windows[j].lastIpcObject
      var members = ipc ? ipc.grouped : null
      if (!members || members.length < 1) continue
      if (ipc.mapped === false) continue

      var key = members.map(normalise).join("|")
      if (seen[key]) continue
      seen[key] = true

      var tabs = []
      var front = -1
      var frontOrder = Infinity

      for (var k = 0; k < members.length; k++) {
        var address = normalise(members[k])
        var window = byAddress[address]
        if (!window) continue

        var meta = window.lastIpcObject || ({})
        if (meta.mapped === false) continue

        var order = typeof meta.focusHistoryID === "number" ? meta.focusHistoryID : Infinity
        if (order < frontOrder) {
          frontOrder = order
          front = tabs.length
        }

        tabs.push({
          address: address,
          title: window.title || meta.class || "Window",
          appClass: meta.class || "",
          active: false,
          focused: address === focusedAddress
        })
      }

      if (tabs.length < 1) continue

      if (front < 0) front = 0
      tabs[front].active = true

      var focused = false
      for (var t = 0; t < tabs.length; t++) if (tabs[t].focused) focused = true

      out.push({ key: key, tabs: tabs, focused: focused })
    }

    return out
  }

  function focus(address) {
    Hyprland.dispatch("focuswindow address:0x" + address)
  }

  function closeTab(address) {
    Hyprland.dispatch("closewindow address:0x" + address)
  }

  property Timer debounce: Timer {
    interval: 40
    onTriggered: {
      Hyprland.refreshToplevels()
      service.revision += 1
      service.settle.restart()
    }
  }

  property Timer settle: Timer {
    interval: 300
    onTriggered: {
      Hyprland.refreshToplevels()
      service.revision += 1
    }
  }

  property Connections events: Connections {
    target: Hyprland

    function onRawEvent(event) {
      switch (event.name) {
      case "openwindow":
      case "closewindow":
      case "movewindow":
      case "movewindowv2":
      case "activewindow":
      case "activewindowv2":
      case "windowtitle":
      case "windowtitlev2":
      case "changefloatingmode":
      case "fullscreen":
      case "togglegroup":
      case "moveintogroup":
      case "moveoutofgroup":
      case "workspace":
      case "workspacev2":
      case "focusedmon":
      case "focusedmonv2":
        service.debounce.restart()
        break
      }
    }
  }

  Component.onCompleted: debounce.restart()
}
