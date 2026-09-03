import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

// Everything the wifi popup knows about NetworkManager.
//
// Polling uses `--rescan no`, which reads NetworkManager's cached scan and
// costs about 15ms. Letting nmcli scan on every poll would cost 4.4s and hold
// the radio busy, so a real scan is only ever what `s` asks for.
//
// Commands are wrapped so they exit 0 and report failure as a leading
// "ERR<TAB>message", the same as the other plugins: reading an exit code would
// race the stdout collector against the process exit.
Item {
  id: service

  property bool active: false

  // [{ ssid, signal, security, secured, active, known }]
  property var networks: []

  property bool radioEnabled: false
  property string device: ""
  property string deviceState: ""
  property string error: ""
  property bool ready: false
  property bool scanning: false

  // ssid -> the action running against it. A row with an entry ignores keys.
  property var busy: ({})
  property int busyRevision: 0
  property string lastActionError: ""

  readonly property var activeNetwork: {
    for (var i = 0; i < networks.length; i++) if (networks[i].active) return networks[i]
    return null
  }

  function isBusy(ssid) {
    busyRevision
    return busy[ssid] !== undefined
  }

  function setBusy(ssid, action) {
    if (action) busy[ssid] = action
    else delete busy[ssid]
    busyRevision += 1
  }

  function unwrap(text) {
    var lines = text.split("\n").filter(function (l) { return l.trim().length > 0 })
    if (lines.length > 0 && lines[0].indexOf("ERR\t") === 0) {
      return { error: lines[0].substring(4), lines: [] }
    }
    return { error: "", lines: lines }
  }

  function refresh() {
    listProcess.running = true
  }

  function absorb(text) {
    var result = unwrap(text)
    ready = true

    if (result.error.length > 0) {
      error = result.error
      networks = []
      return
    }
    error = ""

    // One SSID can appear several times -- two bands, or several access
    // points. Collapse to one row: the connected one if any, else the
    // strongest, so the list does not show the same network three times.
    var best = ({})
    var order = []
    for (var i = 0; i < result.lines.length; i++) {
      var parts = result.lines[i].split("\t")
      if (parts[0] === "RADIO") {
        radioEnabled = parts[1] === "enabled"
      } else if (parts[0] === "DEV" && parts.length >= 4) {
        device = parts[1]
        deviceState = parts[2]
      } else if (parts[0] === "NET" && parts.length >= 6) {
        var row = {
          ssid: parts[1],
          signal: parseInt(parts[2]) || 0,
          security: parts[3] === "open" ? "" : parts[3],
          secured: parts[3] !== "open",
          active: parts[4] === "yes",
          known: parts[5] === "yes"
        }
        var seen = best[row.ssid]
        if (!seen) {
          best[row.ssid] = row
          order.push(row.ssid)
        } else if (row.active || (!seen.active && row.signal > seen.signal)) {
          best[row.ssid] = row
        }
      }
    }

    var rows = []
    for (var j = 0; j < order.length; j++) rows.push(best[order[j]])
    rows.sort(function (a, b) {
      if (a.active !== b.active) return a.active ? -1 : 1
      if (a.known !== b.known) return a.known ? -1 : 1
      return b.signal - a.signal
    })
    networks = rows
  }

  // `nmcli device wifi connect` reuses a stored profile when there is one, so
  // known and new networks take the same path; only the password differs.
  //
  // The password goes in argv, which /proc/<pid>/cmdline exposes to this user
  // for the couple of seconds the command runs. Quickshell's Process has no
  // way to write to stdin, and nmcli will not read a secret from a file, so
  // this is the same trade every nmcli front end makes.
  function connect(ssid, password) {
    if (isBusy(ssid)) return
    setBusy(ssid, "connect")
    lastActionError = ""
    actionProcess.pendingSsid = ssid

    var script = password && password.length > 0
      ? "out=$(timeout 45 nmcli device wifi connect \"$0\" password \"$1\" 2>&1)"
      : "out=$(timeout 45 nmcli device wifi connect \"$0\" 2>&1)"

    actionProcess.command = ["bash", "-c",
      script + " || printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | tail -n1)\"",
      ssid, password || ""]
    actionProcess.running = true
  }

  function disconnect(ssid) {
    if (isBusy(ssid) || device.length === 0) return
    setBusy(ssid, "disconnect")
    lastActionError = ""
    actionProcess.pendingSsid = ssid
    actionProcess.command = ["bash", "-c",
      "out=$(nmcli device disconnect \"$0\" 2>&1) " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | tail -n1)\"",
      device]
    actionProcess.running = true
  }

  // A real scan holds the radio for about four seconds, so it is only ever
  // done on request -- never on the poll timer.
  function rescan() {
    if (scanning) return
    scanning = true
    scanProcess.running = true
  }

  function setRadio(on) {
    if (radioProcess.running) return
    lastActionError = ""
    radioProcess.command = ["bash", "-c",
      "out=$(nmcli radio wifi \"$0\" 2>&1) " +
      "|| printf 'ERR\\t%s\\n' \"$(printf '%s' \"$out\" | head -n1)\"",
      on ? "on" : "off"]
    radioProcess.running = true
  }

  function openEditor() {
    Quickshell.execDetached(["nm-connection-editor"])
  }

  readonly property string listScript:
    // nmcli -t escapes literal colons in values as '\:'; swapping them for
    // \x01 before splitting and back afterwards is the only way to read an
    // SSID containing one.
    "unesc() { printf '%s' \"$1\" | tr '\\001' ':'; }; " +
    "radio=$(nmcli radio wifi 2>&1) || { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$radio\" | head -n1)\"; exit 0; }; " +
    "printf 'RADIO\\t%s\\n' \"$radio\"; " +
    "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null " +
    "| sed 's/\\\\:/\\x01/g' | while IFS=: read -r dev type state conn; do " +
    "[ \"$type\" = wifi ] || continue; " +
    "printf 'DEV\\t%s\\t%s\\t%s\\n' \"$dev\" \"$state\" \"$(unesc \"$conn\")\"; done; " +
    "saved=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | sed 's/\\\\:/\\x01/g' " +
    "| awk -F: '$2 ~ /wireless/ { print $1 }'); " +
    "nets=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>&1) " +
    "|| { printf 'ERR\\t%s\\n' \"$(printf '%s' \"$nets\" | head -n1)\"; exit 0; }; " +
    "printf '%s\\n' \"$nets\" | sed 's/\\\\:/\\x01/g' | while IFS=: read -r inuse ssid signal security; do " +
    "[ -n \"$ssid\" ] || continue; " +
    "printf '%s\\n' \"$saved\" | grep -qxF \"$ssid\" && known=yes || known=no; " +
    "[ \"$inuse\" = '*' ] && act=yes || act=no; " +
    "printf 'NET\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$(unesc \"$ssid\")\" \"$signal\" \"${security:-open}\" \"$act\" \"$known\"; done"

  Process {
    id: listProcess
    command: ["bash", "-c", service.listScript]
    stdout: StdioCollector {
      onStreamFinished: service.absorb(text)
    }
  }

  Process {
    id: actionProcess
    property string pendingSsid: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var result = service.unwrap(text)
        if (result.error) service.lastActionError = result.error
        service.setBusy(actionProcess.pendingSsid, "")
        service.refresh()
      }
    }
  }

  Process {
    id: radioProcess
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
    command: ["bash", "-c", "nmcli device wifi rescan >/dev/null 2>&1 || true"]
    stdout: StdioCollector {
      onStreamFinished: {
        service.scanning = false
        service.refresh()
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: service.active
    onTriggered: service.refresh()
  }
}
