import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

// Everything the calendar popup knows about the agenda.
//
// It reads the cache `zenix agenda fetch` writes on a systemd timer and never
// talks to Google itself. waybar/scripts/agenda.py reads the same file, so the
// bar and the popup cannot disagree, and opening the popup costs a file read
// rather than a network round trip.
//
// The file is watched, so the popup updates itself when the timer fires while
// it happens to be open.
Item {
  id: service

  readonly property string cachePath:
    (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    + "/zenix/agenda.json"

  // The refresher is spelled out rather than called by name: this process is
  // started by hyprland from the display manager, whose PATH is
  // /usr/local/sbin:/usr/local/bin:/usr/bin. ~/.local/bin is added by
  // zsh/.zshrc, which only interactive shells read.
  readonly property string zenixBin: Quickshell.env("HOME") + "/.local/bin/zenix"

  // [{ time, title }] in the order gcalcli returned them.
  property var events: []

  // Whatever stopped the last fetch from producing an agenda: gcalcli missing,
  // OAuth not done, a timeout. Shown in place of the list, because "no events"
  // and "could not ask" are very different things to see.
  property string error: ""

  property string fetchedAt: ""

  property bool loaded: false
  property bool refreshing: false


  function absorb(raw) {
    loaded = true
    try {
      var payload = JSON.parse(raw)
      events = payload.events || []
      error = payload.error || ""
      fetchedAt = payload.fetched_at || ""

    } catch (e) {
      events = []
      error = "unreadable cache"
      fetchedAt = ""
    }
  }

  // How stale the cache is, in minutes, or -1 when it has never been written.
  readonly property int ageMinutes: {
    if (fetchedAt.length === 0) return -1
    var then = Date.parse(fetchedAt)
    if (isNaN(then)) return -1
    return Math.max(0, Math.floor((Date.now() - then) / 60000))
  }

  // Quick-add, in plain language: "lunch with Ana tomorrow 1pm". The parsing
  // is Google's, by way of `gcalcli quick`, so nothing here owns a date
  // grammar. The CLI refreshes the cache on success, so the popup only has to
  // re-read the file.
  // Hands over to the real calendar. execDetached so the popup can close
  // immediately rather than waiting on a browser start.
  function openWeb() {
    Quickshell.execDetached(["xdg-open", "https://calendar.google.com/r/day"])
  }

  function refresh() {
    if (refreshing) return
    refreshing = true
    fetchProcess.running = true
  }

  FileView {
    id: file

    path: service.cachePath
    watchChanges: true

    onFileChanged: reload()
    onLoaded: service.absorb(text())
    onLoadFailed: {
      service.loaded = true
      service.events = []
      service.fetchedAt = ""
      service.error = "no agenda cached yet — the timer writes one every 5 min"
    }
  }

  Process {
    id: fetchProcess

    command: [service.zenixBin, "agenda", "fetch"]

    onExited: {
      service.refreshing = false
      // fetch rewrites the cache; watchChanges usually catches it, but an
      // explicit reload removes the race on a refresh the user asked for.
      file.reload()
    }
  }
}
