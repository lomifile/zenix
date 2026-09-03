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
    tabs/                       the group tab bar along the bottom (always on)
    audio/                      output and input devices (SUPER + S, or the waybar icon)
    bluetooth/                  devices (SUPER + B, or the waybar icon)
    wifi/                       networks (SUPER + W, or the waybar icon)
    calendar/                   month and agenda (click the waybar clock)
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

`autostart` is for a plugin that is part of the desktop rather than something
summoned onto it: the host opens it once the plugin list has settled, without
waiting for an IPC call. Such a plugin still exposes `open`/`close`, so
`zenix-shell shell hide <id>` puts it away for the session. `tabs` is the only
one so far.

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

## Calendar

Click the clock in waybar. The month on the left, today's agenda on the right.
Read-only by design: anything beyond looking hands over to Google Calendar.

| Key | |
|---|---|
| `←` `→`, `h` `l` | previous / next month |
| `t` | back to today |
| `r` | refresh the agenda now |
| `g` | open Google Calendar, and close |
| `Esc` | return to today, then close |

The agenda is read from `~/.cache/zenix/agenda.json` — the same file
`waybar/scripts/agenda.py` reads, written by `zenix agenda fetch` on a systemd
timer. So the popup adds no dependency of its own, cannot disagree with the bar
beside it, and opens in a file read rather than a network round trip. The file
is watched, so a popup left open updates itself when the timer fires.

The day is a real midnight-to-midnight range, given to gcalcli as explicit
dates. Its `today` and `tomorrow` keywords are anchored to *now* instead, which
both hides events earlier in the day and spills into tomorrow morning.

`r` and the timer shell out to `~/.local/bin/zenix` by absolute path: this
process is started by hyprland from the display manager, whose PATH does not
include `~/.local/bin`.

gcalcli missing or unauthenticated is an ordinary answer here, not an error —
the header says which, and `gcalcli init` is usually the fix.

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

## Bluetooth

`SUPER + B`, or click the bluetooth icon in waybar. Paired devices, and one key
to connect or disconnect.

| Key | |
|---|---|
| `↑` `↓`, `j` `k`, `Ctrl-J` `Ctrl-K` | move |
| `Enter`, or a click on the row | connect a disconnected device, disconnect a connected one |
| `t` | trust / untrust |
| `s` | scan for nearby devices |
| `p` | power the adapter on or off |
| `b` | hand over to blueman |
| `/` | filter by name or address |
| `Esc` | clear the filter, then close |

One `bluetoothctl` pass per poll emits the adapter line and a row per device.
`bluetoothctl info` is per-device, so spawning one process each would be the
expensive part; batching the loop into a single shell keeps the whole sweep to
about 90ms. It runs on a 2s timer, and only while the popup is on screen.

Connecting is wrapped in `timeout 25`: a device that is off or out of range
otherwise blocks until bluez gives up, which is far longer than anyone wants a
row to sit spinning.

The list sorts connected first, then paired, so the rows worth acting on stay
at the top as it re-sorts underneath the keys. Selection follows the MAC rather
than the row number for the same reason.

Battery is shown for the devices that report one, amber under 30% and red under
15%. An adapter that is off, a daemon that is not answering and nothing paired
are three different problems, and the empty state says which.

## Wi-Fi

`SUPER + W`, or click the network icon in waybar. Nearby networks, one key to
join or leave, and a password prompt for one that has not been seen before.

| Key | |
|---|---|
| `↑` `↓`, `j` `k`, `Ctrl-J` `Ctrl-K` | move |
| `Enter`, or a click on the row | join; leave if it is the current one |
| `s` | scan again |
| `p` | turn the radio on or off |
| `e` | hand over to nm-connection-editor |
| `/` | filter by name |
| `Esc` | cancel the password, then clear the filter, then close |

`Enter` on a saved or open network joins it straight away. A secured network
that has never been joined asks for a password first; the field takes every
key, since a passphrase can contain `j`, `/` and anything else that is
otherwise a shortcut, and it is drawn as dots.

Polling uses `nmcli ... --rescan no`, which reads NetworkManager's cached scan
and costs about 15ms. A real scan takes 4.4s and holds the radio, so it only
ever happens when `s` asks for it.

One SSID can appear several times -- two bands, or several access points. The
list collapses them to one row, preferring the connected one and otherwise the
strongest, so a network is never listed three times.

`nmcli -t` escapes literal colons in values as `\:`, so the parser swaps them
out before splitting fields and back afterwards. An SSID containing a colon
would otherwise be read as two fields.

The password reaches nmcli in argv, which `/proc/<pid>/cmdline` exposes to this
user for the couple of seconds the command runs. Quickshell's `Process` has no
way to write to stdin and nmcli will not take a secret from a file, so this is
the same trade every nmcli front end makes.

## Sound

`SUPER + S`, or click the volume icon in waybar. Outputs above, inputs below,
each row carrying its own slider.

| Key | |
|---|---|
| `↑` `↓`, `j` `k`, `Ctrl-J` `Ctrl-K` | move |
| `←` `→`, `h` `l` | volume, 5% a step |
| `Shift` + `←` `→` | volume, 1% a step |
| `Enter`, or a click on the row | make this the default device |
| `m`, or a click on the speaker glyph | mute / unmute |
| `p` | hand over to pavucontrol |
| `/` | filter by device name |
| `Esc` | clear the filter, then close |

`pactl -f json` supplies the whole picture in one pass — sinks, sources and
both defaults -- which the service hands straight to `JSON.parse`. The tree
`wpctl status` prints is meant to be read, not parsed, and would need a parser
that breaks the next time a column moves.

Sources ending in `.monitor` are loopbacks of an output, not microphones, and
are dropped: every sink would otherwise appear a second time under Input.

Making a device default also moves the streams already playing through
`move-sink-input`. `set-default-sink` alone only redirects what starts
afterwards, so without it a switch does nothing to the thing you switched for.

Dragging a slider writes through an optimistic value the poll is not allowed to
overwrite: at 1.5s the list would otherwise snap the handle back to the old
volume between the write and the next read. The optimistic value is dropped
400ms after the last write lands, once pipewire has been asked again.

Writes are coalesced to one in flight, with only the latest queued behind it. A
drag across the track emits a value per frame, and spawning a `pactl` per frame
is how you get a slider that lags behind the pointer.

## Tabs

`SUPER + E` folds every tiled window on the workspace into one group — i3's
tabbed layout. The group is then the only tile, so it fills the workspace, and
one window shows at a time. The tabs appear in a pill along the bottom of the
monitor. Pressing it again puts them all back to tiled.

| Key | |
|---|---|
| `SUPER + E` | tab every window on the workspace, or untab them |
| `SUPER + Tab`, `SUPER + Shift + Tab` | next / previous tab |
| click a tab | focus that window |
| middle-click a tab | close that window |

Cycling and the group itself are Hyprland's (`togglegroup`,
`changegroupactive`); the bar is ours, and so is gathering the whole workspace.
`togglegroup` acts on one window, so `toggle_workspace_tabs` in `hyprland.lua`
walks the focused monitor's active workspace, makes a group out of the first
tiled window and `group:add()`s the rest — floating windows left alone, since
a dialog does not belong in the stack. The workspace comes from
`hl.get_active_monitor().active_workspace`: bare `hl.get_active_workspace()`
follows the active *window*, which on a multi-monitor setup can be a workspace
you are not looking at.

Hyprland's own groupbar is turned off in `hyprland.lua`, because it cannot be
moved: `CHyprGroupBarDecoration::getPositioningInfo()` hardcodes
`info.edges = DECORATION_EDGE_TOP`, and `group:groupbar:priority` is decoration
stacking order, not position.

That hardcoded edge is also why this is a strip at the bottom of the screen
rather than a bar on the bottom of each tile. The native groupbar sets
`info.reserved = true`, which is what makes a window shrink to make room for it.
A layer-shell surface cannot reserve space *inside* a tile, so a per-tile bar
would have to be drawn over the bottom of the window — across a terminal's
prompt and an editor's status line. Anchored to the monitor instead, the
exclusive zone reserves the space for real and nothing is ever covered.

The bar exists only while a group does. No groups on the visible workspace and
the window is unmapped and the exclusive zone goes to zero, so the strip costs
no screen height on a workspace that is not using it.

Every group on the workspace gets a segment, divided by a hairline, with the one
holding focus at full strength and the others dimmed. Showing only the focused
group would be less to draw, but a second group would then vanish from a bar
whose whole job is saying what is stacked where.

One bar per monitor, via `Variants` over `Quickshell.screens`, each reading the
active workspace of its own monitor. The 34" at home and the 27" at work are the
same code path rather than a special case.

Group membership comes from `grouped` on each toplevel's `lastIpcObject`, which
Hyprland fills with the group's addresses *in tab order*, so the bar draws them
in the order the keys cycle through. That field only refreshes on
`refreshToplevels()`, so the service asks for one on the events that can change
a group, debounced 40ms to collapse the burst that arrives when a window opens.
