"""One module per top-level command, each wiring its own subparser."""

from zenix.commands import keyboard, status, timezone, wallpaper

MODULES = (status, wallpaper, keyboard, timezone)

__all__ = ["MODULES"]
