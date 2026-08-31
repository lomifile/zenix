"""One module per top-level command, each wiring its own subparser."""

from zenix.commands import agenda, keyboard, status, timezone, wallpaper, webapp

MODULES = (status, wallpaper, keyboard, timezone, webapp, agenda)

__all__ = ["MODULES"]
