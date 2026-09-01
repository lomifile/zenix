# zenix-shell

One long-running [Quickshell](https://quickshell.org/) process that hosts every
custom window on this desktop. `hyprland.lua` starts exactly one per session:

```lua
hl.exec_cmd("qs -p \"$HOME/.config/zenix/shell\"")
```

Nothing else may start Quickshell. That is the whole point — a popup is a
message to a process that is already up, so it appears in tens of milliseconds
instead of paying for a cold QML start every time. Shared state (a palette, a
poller, a service holding a connection) also lives once rather than once per
window.

```
shell/
  shell.qml                     the host: plugin loading and the `shell` IPC target
  Commons/                      Color and Style, imported as `qs.Commons`
  Ui/                           Overlay, KeyHint, StatusDot, imported as `qs.Ui`
  services/
    PluginRegistry.qml          finds plugins and reads their manifests
  plugins/
    containers/                 Docker monitor (SUPER + D)
```

## Talking to it

[`bin/zenix-shell`](../bin/zenix-shell) forwards an IPC call to the running
shell. It never starts one.

```bash
zenix-shell shell ping                          # health check
zenix-shell shell list                          # id, kind, name for every plugin
zenix-shell shell toggle zenix.containers       # open if closed, close if open
zenix-shell shell summon zenix.containers '{}'  # open, with a JSON payload
zenix-shell shell hide zenix.containers
zenix-shell shell rescan                        # re-walk the plugin directories
```

Exit status is 1 when the shell is unreachable or the plugin id is unknown, so
a keybind that does nothing can be told apart from one that is wired up wrong.

## Writing a plugin

A plugin is a directory holding a `manifest.json` and the QML it names. Two
places are searched:

| Directory | What it is |
|---|---|
| `shell/plugins/<id>/` | shipped in this repo, versioned |
| `~/.config/zenix/plugins/<id>/` | drop-ins, not versioned |

A user directory wins over a shipped one with the same id, so trying a change
to a built-in plugin is a copy rather than an edit to the checkout.

```json
{
  "schemaVersion": 1,
  "id": "zenix.containers",
  "name": "Containers",
  "version": "1.0.0",
  "description": "Docker containers at a glance",
  "kinds": ["overlay"],
  "keepLoaded": true,
  "entryPoints": { "overlay": "Containers.qml" }
}
```

`kinds` names what the plugin is. The host can summon `overlay`, `panel` and
`menu`; the first of those it finds is the one it loads. `keepLoaded` keeps the
window mounted between summons — worth it for something opened many times a
day, wasteful for something opened rarely.

The entry point is a plain `Item` exposing three things:

```qml
Item {
  property bool opened: false
  function open(payload) { /* payload is a JSON string, "{}" if none given */ }
  function close() { }
}
```

Most of the window is already written. `Ui/Overlay` supplies the layer-shell
surface, the dimmed backdrop, click-outside and Escape to dismiss, and the
open/close animation, so a plugin is its content and its keys:

```qml
Overlay {
  opened: root.opened
  layerNamespace: "zenix-thing"   // hyprland.lua blurs anything matching ^zenix-
  cardWidth: 620
  cardHeight: 420
  onDismissed: root.close()
  onKeyPressed: function(event) { /* Escape arrives here first */ }

  // content
}
```

Then add a keybind in `hypr/hyprland.lua`:

```lua
hl.bind(mod .. " + D", hl.dsp.exec_cmd("zenix-shell shell toggle zenix.containers"))
```

New directories under `shell/plugins/` need no registration — `install.sh`
links `shell/` as a whole, and the registry finds them on the next start (or on
`zenix-shell shell rescan`).

## Containers

`SUPER + D`. What is running, what it costs, and the four things worth doing
about it without leaving the keyboard.

| Key | |
|---|---|
| `↑` `↓`, `j` `k`, `Ctrl-J` `Ctrl-K` | move |
| `Enter` | start a stopped container, stop a running one |
| `r` | restart |
| `l` | logs, in a floating terminal |
| `s` | a shell inside the container (bash, falling back to sh) |
| `d` | hand over to lazydocker |
| `/` | filter by name or image |
| `Esc` | clear the filter, then close |

`docker ps` drives the list on a 2s timer; `docker stats` fills the CPU and
memory columns on a 4s one, because it samples the daemon for about a second
per call. Both run only while the popup is on screen, so the shell costs
nothing the rest of the day.

The popup is for the glance. Anything wanting scrollback, a prompt or a real
TUI gets a terminal, each with its own app id (`zenix.container-logs`,
`zenix.container-shell`, `zenix.lazydocker`) that `hyprland.lua` floats and
sizes.

Docker being unreachable is an ordinary answer here, not an error: the popup
says so and shows what the daemon replied. `sudo systemctl enable --now docker`
is usually the fix.
