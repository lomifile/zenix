import QtQuick
import Quickshell
import Quickshell.Io

// Finds every plugin the shell can load and reads its manifest.
//
// A plugin is a directory holding a manifest.json plus the QML it names. They
// are looked for in two places: the ones shipped in this repo under
// shell/plugins/, and drop-ins under ~/.config/zenix/plugins/ so a plugin can
// be tried out without touching the checkout. A user directory wins over a
// shipped one with the same id, which is what makes hacking on a built-in
// plugin a copy rather than an edit.
//
// QML has no way to list a directory, so the search itself is one `find`.
Item {
  id: registry

  property string firstPartyDir: ""
  property string userDir: ""

  // [{ id, name, description, kinds, entryPoints, keepLoaded, autostart, dir, firstParty }]
  property var plugins: []

  property bool scanning: false
  property string error: ""

  signal loaded()

  function pluginFor(id) {
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i].id === id) return plugins[i]
    }
    return null
  }

  function entryPointFor(id, kind) {
    var plugin = pluginFor(id)
    if (!plugin || !plugin.entryPoints) return ""
    var file = plugin.entryPoints[kind]
    if (!file) return ""
    return "file://" + plugin.dir + "/" + file
  }

  function rescan() {
    if (scanning) return
    scanning = true
    error = ""
    manifestPaths = []
    scanProcess.running = true
  }

  // Absolute paths to every manifest.json found, in scan order: first party
  // first, so a user plugin declaring the same id overwrites it below.
  property var manifestPaths: []

  // Manifests arrive one at a time and out of order. They are collected into a
  // map keyed by id and only published once every FileView has reported, so
  // consumers never see a half-built plugin list.
  property var collected: ({})
  property int pending: 0

  Process {
    id: scanProcess

    // -mindepth/-maxdepth 2 keeps this to <dir>/<plugin>/manifest.json, so a
    // plugin's own vendored files can never be mistaken for another plugin.
    command: ["bash", "-c",
      "mkdir -p \"$1\" 2>/dev/null; " +
      "find \"$0\" \"$1\" -mindepth 2 -maxdepth 2 -type f -name manifest.json 2>/dev/null | sort",
      registry.firstPartyDir, registry.userDir]

    stdout: StdioCollector {
      onStreamFinished: {
        var paths = text.split("\n").filter(function(line) { return line.length > 0 })
        registry.collected = ({})
        registry.pending = paths.length
        registry.manifestPaths = paths

        if (paths.length === 0) {
          registry.scanning = false
          registry.plugins = []
          registry.loaded()
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: if (text.length > 0) registry.error = text.split("\n")[0]
    }
  }

  // Called by each manifest reader as it finishes, whether or not it parsed.
  function absorb(path, manifest) {
    if (manifest) {
      var dir = path.substring(0, path.lastIndexOf("/"))
      manifest.dir = dir
      manifest.firstParty = dir.indexOf(registry.firstPartyDir) === 0
      registry.collected[manifest.id] = manifest
    }

    pending -= 1
    if (pending > 0) return

    var list = []
    for (var id in registry.collected) list.push(registry.collected[id])
    list.sort(function(a, b) { return (a.name || a.id).localeCompare(b.name || b.id) })

    registry.plugins = list
    registry.scanning = false
    registry.loaded()
  }

  Instantiator {
    model: registry.manifestPaths

    delegate: QtObject {
      required property string modelData

      readonly property FileView view: FileView {
        path: modelData
        onLoaded: {
          var manifest = null
          try {
            manifest = JSON.parse(text())
          } catch (e) {
            console.warn("zenix-shell: unreadable manifest at " + modelData + ": " + e)
          }

          // An id is the only field the host cannot do without: it is how
          // every IPC call names the plugin it wants.
          if (manifest && !manifest.id) {
            console.warn("zenix-shell: manifest without an id at " + modelData)
            manifest = null
          }

          registry.absorb(modelData, manifest)
        }
        onLoadFailed: {
          console.warn("zenix-shell: could not read " + modelData)
          registry.absorb(modelData, null)
        }
      }
    }
  }

  Component.onCompleted: rescan()
}
