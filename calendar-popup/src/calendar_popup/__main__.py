"""Entry point for the calendar-popup command and `python -m calendar_popup`."""

from __future__ import annotations

import sys


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] in ("-h", "--help"):
        print("usage: calendar-popup\n\n"
              "Shows today's Google Calendar agenda in a popup window.\n"
              "Bound to left-click on the waybar clock.")
        return 0
    if argv and argv[0] == "--version":
        from calendar_popup import __version__

        print(f"calendar-popup {__version__}")
        return 0

    import gi

    gi.require_version("Gtk", "3.0")
    from gi.repository import GLib, Gtk

    # Must happen before any window exists: on Wayland GDK reads
    # xdg_toplevel.app_id from the prgname, and that is what the hyprland
    # window rules match on.
    from calendar_popup.window import APP_ID, CalendarTaskWindow

    GLib.set_prgname(APP_ID)

    window = CalendarTaskWindow()
    window.connect("destroy", Gtk.main_quit)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
