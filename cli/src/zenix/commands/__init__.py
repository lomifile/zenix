"""One module per top-level command, each wiring its own subparser."""

from zenix.commands import keyboard, status, timezone, wallpaper, webapp

MODULES = (status, wallpaper, keyboard, timezone, webapp)

__all__ = ["MODULES"]
