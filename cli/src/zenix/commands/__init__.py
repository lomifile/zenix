"""One module per top-level command, each wiring its own subparser."""

from zenix.commands import (
    agenda,
    config,
    display,
    keyboard,
    nightlight,
    status,
    theme,
    timezone,
    wallpaper,
    webapp,
)

MODULES = (status, config, display, nightlight, theme, wallpaper, keyboard, timezone, webapp, agenda)

__all__ = ["MODULES"]
