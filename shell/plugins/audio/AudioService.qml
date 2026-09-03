import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  property bool active: false

  property var sinks: []
  property var sources: []
  property string defaultSink: ""
  property string defaultSource: ""

  property string error: ""
  property bool ready: false
  property string lastActionError: ""

  property var busy: ({})
  property int busyRevision: 0

  property var pending: ({})
  property int pendingRevision: 0
  property var queued: null

  readonly property var defaultSinkNode: nodeFor("sink", defaultSink)
  readonly property var defaultSourceNode: nodeFor("source", defaultSource)

  function nodeFor(kind, name) {
    var list = kind === "sink" ? sinks : sources
    for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
    return null
  }

  function isBusy(name) {
    busyRevision
    return busy[name] !== undefined
  }

  function setBusy(name, action) {
    if (action) busy[name] = action
    else delete busy[name]
    busyRevision += 1
  }

  function volumeOf(node) {
    pendingRevision
    if (!node) return 0
    if (pending[node.name] !== undefined) return pending[node.name]
    return node.volume
  }

  function refresh() {
    if (!listProcess.running) listProcess.running = true
  }

  function unwrap(text) {
    var lines = text.split("\n").filter(function (line) { return line.trim().length > 0 })
    if (lines.length > 0 && lines[0].indexOf("ERR\t") === 0) {
      return { error: lines[0].substring(4), lines: [] }
    }
    return { error: "", lines: lines }
  }

  function normalise(raw, kind) {
    var out = []
    for (var i = 0; i < raw.length; i++) {
      var node = raw[i]
      if (kind === "source" && /\.monitor$/.test(node.name)) continue

      var channels = node.volume ? Object.keys(node.volume) : []
      var total = 0
      for (var c = 0; c < channels.length; c++) total += node.volume[channels[c]].value
      var percent = channels.length > 0
        ? Math.round((total / channels.length) / 65536 * 100)
        : 0

      out.push({
        kind: kind,
        name: node.name,
        description: node.description || node.name,
        mute: node.mute === true,
        state: node.state || "",
        volume: percent
      })
    }
    out.sort(function (a, b) { return a.description.localeCompare(b.description) })
    return out
  }

  function absorb(text) {
    var result = unwrap(text)
    ready = true

    if (result.error.length > 0) {
      error = result.error
      sinks = []
      sources = []
      return
    }

    var nextSinks = sinks
    var nextSources = sources
    var nextDefaultSink = defaultSink
    var nextDefaultSource = defaultSource

    for (var i = 0; i < result.lines.length; i++) {
      var line = result.lines[i]
      var tab = line.indexOf("\t")
      if (tab < 0) continue

      var key = line.substring(0, tab)
      var value = line.substring(tab + 1)

      try {
        if (key === "DEFSINK") nextDefaultSink = value
        else if (key === "DEFSRC") nextDefaultSource = value
        else if (key === "SINKS") nextSinks = normalise(JSON.parse(value), "sink")
        else if (key === "SOURCES") nextSources = normalise(JSON.parse(value), "source")
      } catch (e) {
        error = "could not read pactl output: " + e
        return
      }
    }

    error = ""
    sinks = nextSinks
    sources = nextSources
    defaultSink = nextDefaultSink
    defaultSource = nextDefaultSource
  }

  function setDefault(node) {
    if (!node || isBusy(node.name)) return
    if (node.kind === "sink" ? defaultSink === node.name : defaultSource === node.name) return

    setBusy(node.name, "default")
    lastActionError = ""
    defaultProcess.pendingName = node.name
    defaultProcess.pendingLabel = node.description
    defaultProcess.command = ["bash", "-c",
      "kind=$0; name=$1; " +
      "out=$(pactl set-default-$kind \"$name\" 2>&1) " +
      "|| { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\"; exit 0; }; " +
      "if [ \"$kind\" = sink ]; then " +
      "pactl list short sink-inputs 2>/dev/null | cut -f1 | " +
      "while read -r id; do pactl move-sink-input \"$id\" \"$name\" >/dev/null 2>&1 || true; done; " +
      "else " +
      "pactl list short source-outputs 2>/dev/null | cut -f1 | " +
      "while read -r id; do pactl move-source-output \"$id\" \"$name\" >/dev/null 2>&1 || true; done; " +
      "fi",
      node.kind, node.name]
    defaultProcess.running = true
  }

  function toggleMute(node) {
    if (!node) return
    lastActionError = ""
    muteProcess.command = ["bash", "-c",
      "out=$(pactl set-$0-mute \"$1\" toggle 2>&1) " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\"",
      node.kind, node.name]
    muteProcess.running = true
  }

  function setVolume(node, percent) {
    if (!node) return
    var clamped = Math.max(0, Math.min(100, Math.round(percent)))

    pending[node.name] = clamped
    pendingRevision += 1

    queued = { kind: node.kind, name: node.name, percent: clamped }
    if (!volumeProcess.running) flush()
  }

  function nudge(node, delta) {
    if (!node) return
    setVolume(node, volumeOf(node) + delta)
  }

  function flush() {
    if (!queued || volumeProcess.running) return

    var job = queued
    queued = null
    volumeProcess.pendingName = job.name
    volumeProcess.command = ["bash", "-c",
      "out=$(pactl set-$0-volume \"$1\" \"$2%\" 2>&1) " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\"",
      job.kind, job.name, String(job.percent)]
    volumeProcess.running = true
  }

  function openMixer() {
    Quickshell.execDetached(["pavucontrol"])
  }

  Process {
    id: listProcess

    command: ["bash", "-c",
      "ds=$(pactl get-default-sink 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$ds\" | head -n1)\"; exit 0; }; " +
      "dr=$(pactl get-default-source 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$dr\" | head -n1)\"; exit 0; }; " +
      "sk=$(pactl -f json list sinks 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$sk\" | head -n1)\"; exit 0; }; " +
      "sr=$(pactl -f json list sources 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$sr\" | head -n1)\"; exit 0; }; " +
      "printf 'DEFSINK\\t%s\\n' \"$ds\"; " +
      "printf 'DEFSRC\\t%s\\n' \"$dr\"; " +
      "printf 'SINKS\\t%s\\n' \"$(printf '%s' \"$sk\" | tr -d '\\n')\"; " +
      "printf 'SOURCES\\t%s\\n' \"$(printf '%s' \"$sr\" | tr -d '\\n')\""]

    stdout: StdioCollector {
      onStreamFinished: service.absorb(text)
    }
  }

  Process {
    id: defaultProcess

    property string pendingName: ""
    property string pendingLabel: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) {
          service.lastActionError = defaultProcess.pendingLabel + ": " + result.error
        }
        service.setBusy(defaultProcess.pendingName, "")
        service.refresh()
      }
    }
  }

  Process {
    id: muteProcess

    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) service.lastActionError = result.error
        service.refresh()
      }
    }
  }

  Process {
    id: volumeProcess

    property string pendingName: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) service.lastActionError = result.error

        if (service.queued) {
          service.flush()
        } else {
          settleTimer.settling = volumeProcess.pendingName
          settleTimer.restart()
        }
      }
    }
  }

  Timer {
    id: settleTimer

    property string settling: ""

    interval: 400
    onTriggered: {
      if (service.queued) return
      delete service.pending[settleTimer.settling]
      service.pendingRevision += 1
      service.refresh()
    }
  }

  Timer {
    interval: 1500
    repeat: true
    running: service.active
    onTriggered: service.refresh()
  }
}
