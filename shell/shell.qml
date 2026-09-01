import QtQuick
import Quickshell
import Quickshell.Io

import "services"

// zenix-shell: one long-running Quickshell process that hosts every custom
// window on this desktop. Hyprland starts exactly one of these per session and
// nothing else spawns Quickshell; popups are summoned over IPC into a process
// that is already up, which is the difference between a window appearing in
// ~30ms and waiting out a cold QML start every time.
//
//   zenix-shell shell ping
//   zenix-shell shell toggle zenix.containers
//   zenix-shell shell list
//
// See shell/README.md for the plugin contract.
ShellRoot {
  id: shell

  // The directory this file sits in, recovered from its own URL so the shell
  // works from a checkout, a symlink into ~/.config, or anywhere else without
  // an environment variable having to agree with it.
  readonly property string shellDir: String(Qt.resolvedUrl("."))
    .replace(/^file:\/\//, "")
    .replace(/\/$/, "")

  readonly property string home: Quickshell.env("HOME")
  readonly property string userPluginDir: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/zenix/plugins"

  PluginRegistry {
    id: registry
    firstPartyDir: shell.shellDir + "/plugins"
    userDir: shell.userPluginDir
  }

  // pluginId -> the holder object below, so IPC can reach a specific plugin.
  property var holders: ({})

  // Kinds this host knows how to summon. A plugin declaring none of them is
  // still discovered and listed, it simply has no window to open.
  readonly property var summonableKinds: ["overlay", "panel", "menu"]

  function summonableKind(manifest) {
    if (!manifest || !manifest.kinds) return ""
    for (var i = 0; i < summonableKinds.length; i++) {
      if (manifest.kinds.indexOf(summonableKinds[i]) !== -1) return summonableKinds[i]
    }
    return ""
  }

  Instantiator {
    model: registry.plugins

    delegate: QtObject {
      id: holder

      required property var modelData

      readonly property string pluginId: modelData.id
      readonly property string kind: shell.summonableKind(modelData)
      // A plugin that keeps its window mounted between summons reopens without
      // re-reading anything. Worth it for a window opened many times a day;
      // wasteful for one opened rarely, which is why it is per-plugin.
      readonly property bool keepLoaded: modelData.keepLoaded === true

      readonly property string entry: kind === ""
        ? ""
        : "file://" + modelData.dir + "/" + (modelData.entryPoints ? modelData.entryPoints[kind] || "" : "")

      readonly property LazyLoader loader: LazyLoader {
        // Never bound: open() sets this directly so that the component is
        // guaranteed loaded by the time open() goes on to call into it.
        // Quickshell finishes a pending background load synchronously here.
        active: false
        source: holder.entry
      }

      function open(payload) {
        if (entry === "") return "not summonable"

        loader.active = true
        if (!loader.item) return "failed to load"

        if (typeof loader.item.open === "function") loader.item.open(payload || "{}")
        else loader.item.opened = true
        return "ok"
      }

      function hide() {
        if (!loader.item) return "ok"

        if (typeof loader.item.close === "function") loader.item.close()
        else loader.item.opened = false

        // Tearing the window down while it is still fading out would make the
        // close look like a cut, so the unload waits for the animation.
        if (!keepLoaded) unloadTimer.restart()
        return "ok"
      }

      function isOpen() {
        return loader.item ? loader.item.opened === true : false
      }

      readonly property Timer unloadTimer: Timer {
        interval: 400
        onTriggered: if (!holder.isOpen()) holder.loader.active = false
      }

      Component.onCompleted: shell.holders[pluginId] = holder
      Component.onDestruction: delete shell.holders[pluginId]
    }
  }

  IpcHandler {
    target: "shell"

    function ping(): string {
      return "ok"
    }

    function summon(id: string, payload: string): string {
      var holder = shell.holders[id]
      if (!holder) return "unknown plugin: " + id
      return holder.open(payload)
    }

    function hide(id: string): string {
      var holder = shell.holders[id]
      if (!holder) return "unknown plugin: " + id
      return holder.hide()
    }

    function toggle(id: string, payload: string): string {
      var holder = shell.holders[id]
      if (!holder) return "unknown plugin: " + id
      return holder.isOpen() ? holder.hide() : holder.open(payload)
    }

    // Newline-separated "<id>\t<kind>\t<name>", which is enough for a shell
    // script to pick a plugin out with awk and for a human to read directly.
    function list(): string {
      var lines = []
      for (var i = 0; i < registry.plugins.length; i++) {
        var plugin = registry.plugins[i]
        var kind = shell.summonableKind(plugin) || (plugin.kinds || []).join(",") || "-"
        lines.push(plugin.id + "\t" + kind + "\t" + (plugin.name || plugin.id))
      }
      return lines.join("\n")
    }

    function rescan(): string {
      registry.rescan()
      return "ok"
    }
  }
}
