import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

// Everything the bluetooth popup knows about the adapter and its devices.
//
// Polling only runs while `active` is true -- while the popup is on screen --
// so a shell that is up all day costs nothing until it is asked. One bash
// pass emits the adapter line and a row per device, because `bluetoothctl
// info` is per-device and spawning one process each would be the expensive
// part; the whole sweep measures around 90ms.
//
// Commands are wrapped so they exit 0 and report failure as a leading
// "ERR<TAB>message". Reading an exit code would mean racing the stdout
// collector against the process exit; one stream with the error inside it has
// no such race, and an adapter that is off is an ordinary answer here.
Item {
  id: service

  property bool active: false

  // [{ mac, name, connected, paired, trusted, icon, battery }]
  property var devices: []

  property bool adapterPresent: false
  property bool adapterPowered: false
  property string adapterName: ""

  // Set when bluetoothctl itself cannot answer: no adapter, bluetoothd down.
  property string error: ""
  property bool ready: false

  // mac -> the action running against it ("connect", "disconnect", ...).
  property var busy: ({})
  // Mutating a JS object in place does not notify bindings that read it.
  property int busyRevision: 0
  property string lastActionError: ""

  readonly property int connectedCount: {
    var n = 0
    for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++
    return n
  }

  function isBusy(mac) {
    busyRevision            // read so this re-evaluates when busy changes
    return busy[mac] !== undefined
  }

  function setBusy(mac, action) {
    if (action) busy[mac] = action
    else delete busy[mac]
    busyRevision += 1
  }

  function unwrap(text) {
    var lines = text.split("\n").filter(function (line) { return line.trim().length > 0 })
    if (lines.length > 0 && lines[0].indexOf("ERR\t") === 0) {
      return { error: lines[0].substring(4), lines: [] }
    }
    return { error: "", lines: lines }
  }

  function refresh() {
    if (!scanProcess.running) listProcess.running = true
  }

  function absorb(text) {
    var result = unwrap(text)
    ready = true

    if (result.error.length > 0) {
      error = result.error
      devices = []
      adapterPresent = false
      return
    }
    error = ""

    var rows = []
    for (var i = 0; i < result.lines.length; i++) {
      var parts = result.lines[i].split("\t")
      if (parts[0] === "ADAPTER") {
        adapterPresent = true
        adapterPowered = parts[1] === "yes"
        adapterName = parts[2] || ""
      } else if (parts[0] === "DEV" && parts.length >= 8) {
        rows.push({
          mac: parts[1],
          name: parts[2].length > 0 ? parts[2] : parts[1],
          connected: parts[3] === "yes",
          paired: parts[4] === "yes",
          trusted: parts[5] === "yes",
          icon: parts[6],
          battery: parts[7]
        })
      }
    }

    // Connected first, then paired, then the rest -- the ones worth acting on
    // stay at the top as the list re-sorts under the keys.
    rows.sort(function (a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.paired !== b.paired) return a.paired ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    devices = rows
  }

  // The one action worth a single key: whatever this device is doing, do the
  // opposite.
  function toggle(device) {
    if (!device || isBusy(device.mac)) return
    run(device.connected ? "disconnect" : "connect", device.mac, device.name)
  }

  function run(verb, mac, name) {
    if (isBusy(mac)) return
    setBusy(mac, verb)
    lastActionError = ""
    actionProcess.pendingMac = mac
    actionProcess.pendingName = name
    // `timeout` matters here: connecting to a device that is off or out of
    // range blocks until bluez gives up, which is far longer than anyone
    // wants a row to sit spinning.
    actionProcess.command = ["bash", "-c",
      "out=$(timeout 25 bluetoothctl \"$0\" \"$1\" 2>&1) " +
      "&& printf '%s' \"$out\" | grep -qiE 'fail|error|not available' " +
      "&& printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | tail -n1)\" " +
      "|| true",
      verb, mac]
    actionProcess.running = true
  }

  function setPower(on) {
    if (powerProcess.running) return
    lastActionError = ""
    powerProcess.command = ["bash", "-c",
      "out=$(bluetoothctl power \"$0\" 2>&1) " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\"",
      on ? "on" : "off"]
    powerProcess.running = true
  }

  // A timed scan: bluetoothctl would otherwise sit in a discovery loop with
  // nothing to stop it. Newly seen devices turn up in the next poll.
  property bool scanning: scanProcess.running
  function scan() {
    if (scanProcess.running) return
    scanProcess.running = true
  }

  function openManager() {
    Quickshell.execDetached(["blueman-manager"])
  }

  Process {
    id: listProcess

    command: ["bash", "-c",
      "show=$(bluetoothctl show 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$show\" | head -n1)\"; exit 0; }; " +
      "printf 'ADAPTER\\t%s\\t%s\\n' " +
      "\"$(printf '%s' \"$show\" | sed -n 's/^[[:space:]]*Powered:[[:space:]]*//p' | head -1)\" " +
      "\"$(printf '%s' \"$show\" | sed -n 's/^[[:space:]]*Alias:[[:space:]]*//p' | head -1)\"; " +
      "devs=$(bluetoothctl devices 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$devs\" | head -n1)\"; exit 0; }; " +
      "printf '%s\\n' \"$devs\" | while read -r _ mac rest; do " +
      "[ -n \"$mac\" ] || continue; " +
      "info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
      "field() { printf '%s' \"$info\" | sed -n \"s/^[[:space:]]*$1:[[:space:]]*//p\" | head -1; }; " +
      "printf 'DEV\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' " +
      "\"$mac\" \"$(field Alias)\" \"$(field Connected)\" \"$(field Paired)\" " +
      "\"$(field Trusted)\" \"$(field Icon)\" " +
      "\"$(printf '%s' \"$info\" | sed -n 's/.*Battery Percentage:[^(]*(\\([0-9]*\\)).*/\\1/p' | head -1)\"; " +
      "done"]

    stdout: StdioCollector {
      onStreamFinished: service.absorb(text)
    }
  }

  Process {
    id: actionProcess

    property string pendingMac: ""
    property string pendingName: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) {
          service.lastActionError = actionProcess.pendingName + ": " + result.error
        }
        service.setBusy(actionProcess.pendingMac, "")
        service.refresh()
      }
    }
  }

  Process {
    id: powerProcess
    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) service.lastActionError = result.error
        service.refresh()
      }
    }
  }

  Process {
    id: scanProcess
    command: ["bash", "-c", "bluetoothctl --timeout 12 scan on >/dev/null 2>&1 || true"]
    stdout: StdioCollector {
      onStreamFinished: service.refresh()
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: service.active
    onTriggered: service.refresh()
  }
}
