import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

// Everything the containers popup knows about Docker.
//
// Polling only runs while `active` is true -- that is, while the popup is on
// screen -- so a shell that is up all day costs nothing until it is asked a
// question. `docker ps` is cheap and drives the list; `docker stats` samples
// the daemon for a second or so per call and only supplies the CPU and memory
// columns, so it runs on its own slower timer and is merged in by id.
//
// Every command is wrapped so that it exits 0 and reports failure as a leading
// "ERR<TAB>message" line. Reading an exit code would mean racing the stdout
// collector against the process exit; one stream with the error inside it has
// no such race, and a daemon that is down is an ordinary answer here rather
// than an exception.
Item {
  id: service

  property bool active: false

  // [{ id, name, image, state, status, ports, uptime, cpu, mem, health }]
  property var containers: []

  // Set when Docker itself cannot be reached: not installed, daemon down,
  // socket not permitted. The popup shows this instead of an empty list, since
  // "no containers" and "no daemon" are very different things to see.
  property string error: ""

  // False until the first poll has come back, so the popup can say "loading"
  // rather than flashing an empty state on the way in.
  property bool ready: false

  // id -> the action currently running against it ("stop", "restart", ...).
  // A row with an entry here shows a pulsing dot and ignores further keys.
  property var busy: ({})

  // Bumped on every change to `busy`, because mutating a JS object in place
  // does not notify QML bindings that read it.
  property int busyRevision: 0

  property string lastActionError: ""

  readonly property int runningCount: countState("running")
  readonly property int stoppedCount: containers.length - runningCount

  function countState(state) {
    var n = 0
    for (var i = 0; i < containers.length; i++) {
      if (containers[i].state === state) n += 1
    }
    return n
  }

  function isBusy(id) {
    // Touch the revision so this re-evaluates when `busy` is mutated.
    return busyRevision >= 0 && busy[id] !== undefined
  }

  function setBusy(id, action) {
    if (action) busy[id] = action
    else delete busy[id]
    busyRevision += 1
  }

  // --- polling -------------------------------------------------------------

  function refresh() {
    if (!psProcess.running) psProcess.running = true
  }

  function refreshStats() {
    if (!statsProcess.running && runningCount > 0) statsProcess.running = true
  }

  onActiveChanged: {
    if (active) {
      refresh()
      refreshStats()
    } else {
      // A poll in flight is left to finish rather than killed: it is about to
      // deliver state the next open would otherwise have to fetch again.
      lastActionError = ""
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: service.active
    onTriggered: service.refresh()
  }

  Timer {
    interval: 4000
    repeat: true
    running: service.active
    onTriggered: service.refreshStats()
  }

  // --- parsing -------------------------------------------------------------

  // Splits a wrapped command's output into its error line, if any, and the
  // JSON lines behind it.
  function unwrap(text) {
    var lines = text.split("\n").filter(function(line) { return line.trim().length > 0 })
    if (lines.length > 0 && lines[0].indexOf("ERR\t") === 0) {
      return { error: lines[0].substring(4), lines: [] }
    }
    return { error: "", lines: lines }
  }

  // "Up 4 hours (healthy)" -> "healthy". Docker only reports this for images
  // that declare a HEALTHCHECK, so most containers have no health at all and
  // that is not a problem to report.
  function healthOf(status) {
    var match = /\((healthy|unhealthy|health: starting)\)/.exec(status || "")
    if (!match) return ""
    return match[1] === "health: starting" ? "starting" : match[1]
  }

  // "Up 4 hours (healthy)" -> "Up 4 hours". The health is shown as color on
  // the dot, so repeating it in the text would just crowd the row.
  function trimStatus(status) {
    return (status || "").replace(/\s*\((healthy|unhealthy|health: starting)\)\s*/, "").trim()
  }

  // Docker prints ports as "0.0.0.0:8080->80/tcp, [::]:8080->80/tcp". Both
  // families map the same port, so the v6 half is dropped, and only the
  // published side is kept -- the container-side port is rarely what you are
  // looking for when scanning a list.
  function shortPorts(ports) {
    if (!ports) return ""
    var seen = {}
    var out = []
    var parts = ports.split(",")
    for (var i = 0; i < parts.length; i++) {
      var match = /:(\d+)->/.exec(parts[i].trim())
      if (!match) continue
      if (seen[match[1]]) continue
      seen[match[1]] = true
      out.push(match[1])
    }
    return out.join(" ")
  }

  // "12.5MiB / 7.658GiB" -> "12.5MiB". The limit is the same for every
  // container on the host, so showing it on every row spends width on a
  // constant.
  function usedMemory(memUsage) {
    if (!memUsage) return ""
    return memUsage.split("/")[0].trim()
  }

  function absorbPs(text) {
    var result = unwrap(text)
    if (result.error) {
      service.error = result.error
      service.ready = true
      return
    }

    var rows = []
    for (var i = 0; i < result.lines.length; i++) {
      var raw
      try {
        raw = JSON.parse(result.lines[i])
      } catch (e) {
        continue
      }

      rows.push({
        id: raw.ID || "",
        name: raw.Names || "",
        image: raw.Image || "",
        state: raw.State || "",
        status: trimStatus(raw.Status),
        health: healthOf(raw.Status),
        ports: shortPorts(raw.Ports),
        // Carried over from the previous merge so the columns do not blank out
        // between the faster ps poll and the slower stats poll.
        cpu: previousField(raw.ID, "cpu"),
        mem: previousField(raw.ID, "mem")
      })
    }

    // Running first, then alphabetical. Names are what the eye searches by,
    // and a stopped container is rarely what the popup was opened for.
    rows.sort(function(a, b) {
      var aRunning = a.state === "running" ? 0 : 1
      var bRunning = b.state === "running" ? 0 : 1
      if (aRunning !== bRunning) return aRunning - bRunning
      return a.name.localeCompare(b.name)
    })

    service.containers = rows
    service.error = ""
    service.ready = true
  }

  function previousField(id, field) {
    for (var i = 0; i < containers.length; i++) {
      if (containers[i].id === id) return containers[i][field]
    }
    return ""
  }

  function absorbStats(text) {
    var result = unwrap(text)
    // A stats failure is not worth surfacing on its own: ps is the source of
    // truth for whether Docker is reachable, and losing two columns for a poll
    // is less disruptive than replacing the list with an error.
    if (result.error) return

    var byId = ({})
    for (var i = 0; i < result.lines.length; i++) {
      var raw
      try {
        raw = JSON.parse(result.lines[i])
      } catch (e) {
        continue
      }
      byId[raw.ID] = raw
    }

    var rows = []
    for (var j = 0; j < containers.length; j++) {
      var row = containers[j]
      var stat = byId[row.id]
      rows.push({
        id: row.id,
        name: row.name,
        image: row.image,
        state: row.state,
        status: row.status,
        health: row.health,
        ports: row.ports,
        cpu: stat ? (stat.CPUPerc || "") : "",
        mem: stat ? usedMemory(stat.MemUsage) : ""
      })
    }
    service.containers = rows
  }

  Process {
    id: psProcess

    command: ["bash", "-c",
      "out=$(docker ps -a --format '{{json .}}' 2>&1) " +
      "&& printf '%s\\n' \"$out\" " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\""]

    stdout: StdioCollector {
      onStreamFinished: service.absorbPs(text)
    }
  }

  Process {
    id: statsProcess

    command: ["bash", "-c",
      "out=$(docker stats --no-stream --format '{{json .}}' 2>&1) " +
      "&& printf '%s\\n' \"$out\" " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\""]

    stdout: StdioCollector {
      onStreamFinished: service.absorbStats(text)
    }
  }

  // --- actions -------------------------------------------------------------

  // Runs one `docker <verb> <id>` and refreshes. `stop` waits out the
  // container's grace period, which is why the row stays busy rather than
  // optimistically flipping to stopped.
  function run(verb, id, name) {
    if (isBusy(id)) return
    setBusy(id, verb)
    lastActionError = ""
    actionProcess.pendingId = id
    actionProcess.pendingName = name
    actionProcess.command = ["bash", "-c",
      "out=$(docker \"$0\" \"$1\" 2>&1) " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\"",
      verb, id]
    actionProcess.running = true
  }

  Process {
    id: actionProcess

    property string pendingId: ""
    property string pendingName: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) {
          service.lastActionError = actionProcess.pendingName + ": " + result.error
        }
        service.setBusy(actionProcess.pendingId, "")
        service.refresh()
        service.refreshStats()
      }
    }
  }

  // Hands a container off to a terminal. These are the things a popup should
  // not try to be: a log pager, a shell, a full TUI. Each gets its own app id
  // so hyprland.lua can float and size them.
  function openLogs(id, name) {
    Quickshell.execDetached(["ghostty", "--class=zenix.container-logs",
      "--title=logs: " + name,
      "-e", "bash", "-c", "docker logs -f --tail 200 " + id])
  }

  function openShell(id, name) {
    // Not every image has bash; falling back to sh covers alpine and friends.
    Quickshell.execDetached(["ghostty", "--class=zenix.container-shell",
      "--title=shell: " + name,
      "-e", "bash", "-c",
      "docker exec -it " + id + " bash || docker exec -it " + id + " sh"])
  }

  function openLazydocker() {
    Quickshell.execDetached(["ghostty", "--class=zenix.lazydocker",
      "--title=lazydocker", "-e", "lazydocker"])
  }
}
