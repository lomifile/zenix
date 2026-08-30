# calendar-popup

A GTK3 popup showing today's Google Calendar agenda, bound to left-click on the
[zenix](..) waybar clock.

## Runtime requirements

Neither can be expressed as a wheel dependency, so both come from
`packages/pacman.txt` and `packages/aur.txt`:

| Need        | Provided by            | Why                                    |
|-------------|------------------------|----------------------------------------|
| `gi` / GTK3 | `python-gobject`, `gtk3` | PyGObject is a distro package, not a wheel |
| `gcalcli`   | AUR                    | external command, needs Google OAuth   |

Because `gi` lives in the system interpreter, `install.sh` installs this with
`pipx install --system-site-packages`; a plain isolated venv cannot import it.

`gcalcli init` has to be run once by hand — the OAuth handshake is interactive.
Until then the popup shows "Authentication required."

## Window identity

`main()` calls `GLib.set_prgname("calendar-tasks")` **before** any window
exists, because on Wayland GDK takes `xdg_toplevel.app_id` from the prgname.
That is what the `hl.window_rule` entries in `hypr/hyprland.lua` match on;
`Gtk.Window.set_wmclass()` is X11-only and would not work.

## Building

`install.sh` does this. By hand:

```sh
python -m build --wheel --no-isolation
pipx install --force --system-site-packages dist/calendar_popup-*.whl
```
