"""Shared fixtures: a throwaway zenix checkout and output capture."""

from __future__ import annotations

import io
import json
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory

_SRC = str(Path(__file__).resolve().parent.parent / "src")
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)

from zenix.context import Context  # noqa: E402
from zenix.repo import Repo  # noqa: E402

INSTALL_SH = """#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_NAME="desk.png"
GREETER_WALLPAPER_NAME="greet.jpg"
THEME_NAME="fixture"
"""

# Carries the theme block and the four app-theme lines as well as the input
# table: a repo without them is one the generator will (correctly) refuse to
# write, so a fixture without them would not be a valid checkout.
HYPRLAND_LUA = """-- >>> zenix theme <<<
local c = {
\tborder_active_1 = "rgba(ffffffcc)",
\tborder_active_2 = "rgba(ffffff55)",
\tborder_inactive = "rgba(ffffff22)",
\tgroup_active = "rgba(0a84ffcc)",
\tgroup_inactive = "rgba(ffffff22)",
\tshadow = 0x40000000,
}
-- >>> end zenix theme <<<

hl.env("GTK_THEME", "Adwaita:dark")

hl.on("hyprland.start", function()
\thl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
\thl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
\thl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
end)

return {
\tinput = {
\t\tkb_layout = "us",
\t\tfollow_mouse = 1,
\t},
}
"""

ARCHINSTALL = {
    "locale_config": {"kb_layout": "us", "sys_lang": "en_US.UTF-8"},
    "timezone": "Europe/Zagreb",
}

FIXTURE_THEME = {
    "meta": {
        "name": "fixture",
        "label": "Fixture Theme",
        "background": "dark"
    },
    "editor": {
        "bg": "#110101",
        "bg_line": "#120202",
        "bg_panel": "#130303",
        "bg_sel": "#140404",
        "bg_float": "#150505",
        "bg_chrome": "#160606",
        "bg_tab": "#170707",
        "chrome_line": "#180808",
        "fg": "#190909",
        "fg_dim": "#1a0a0a",
        "comment": "#1b0b0b",
        "gutter": "#1c0c0c",
        "pink": "#1d0d0d",
        "salmon": "#1e0e0e",
        "sand": "#1f0f0f",
        "orange": "#201010",
        "teal": "#211111",
        "mint": "#221212",
        "cyan": "#231313",
        "steel": "#241414",
        "lilac": "#251515",
        "purple": "#261616",
        "select_blue": "#271717",
        "highlight_yellow": "#281818",
        "diff_add": "#291919",
        "diff_delete": "#2a1a1a",
        "diff_text": "#2b1b1b",
        "indent_marker": "#2c1c1c",
        "backdrop": "#2d1d1d",
        "red": "#2e1e1e",
        "green": "#2f1f1f",
        "yellow": "#302020",
        "blue": "#312121"
    },
    "terminal": {
        "palette": [
            "#322222",
            "#332323",
            "#342424",
            "#352525",
            "#362626",
            "#372727",
            "#382828",
            "#392929",
            "#3a2a2a",
            "#3b2b2b",
            "#3c2c2c",
            "#3d2d2d",
            "#3e2e2e",
            "#3f2f2f",
            "#403030",
            "#413131"
        ],
        "background": "#423232",
        "foreground": "#433333",
        "cursor": "#443434",
        "cursor_text": "#453535",
        "selection_bg": "#463636",
        "selection_fg": "#473737"
    },
    "desktop": {
        "surface": "#483838",
        "card": "#80493939",
        "elevated": "#804a3a3a",
        "separator": "#804b3b3b",
        "border": "#804c3c3c",
        "scrim": "#804d3d3d",
        "foreground": "#4e3e3e",
        "muted": "#4f3f3f",
        "faint": "#504040",
        "grey": "#514141",
        "accent": "#524242",
        "on_accent": "#534343",
        "selection": "#80544444",
        "status_good": "#554545",
        "status_warn": "#564646",
        "status_alert": "#574747",
        "status_bad": "#584848"
    },
    "washes": {
        "faint": "#80594949",
        "dim": "#805a4a4a",
        "soft": "#805b4b4b",
        "base": "#805c4c4c",
        "border": "#805d4d4d",
        "hover": "#805e4e4e",
        "strong": "#805f4f4f",
        "bold": "#80605050"
    },
    "css": {
        "pill_bg": "rgba(1, 2, 3, 0.5)",
        "pill_border": "rgba(1, 2, 3, 0.5)",
        "hover": "rgba(1, 2, 3, 0.5)",
        "tooltip_bg": "rgba(1, 2, 3, 0.5)",
        "tooltip_border": "rgba(1, 2, 3, 0.5)",
        "wofi_bg": "rgba(1, 2, 3, 0.5)",
        "wofi_border": "rgba(1, 2, 3, 0.5)",
        "wofi_hairline": "rgba(1, 2, 3, 0.5)",
        "wofi_selected": "rgba(1, 2, 3, 0.5)",
        "wofi_fg": "#615151",
        "wofi_text": "rgba(1, 2, 3, 0.5)",
        "wofi_placeholder": "rgba(1, 2, 3, 0.5)"
    },
    "hypr": {
        "border_active_1": "rgba(0102030f)",
        "border_active_2": "rgba(0102030f)",
        "border_inactive": "rgba(0102030f)",
        "group_border_active": "rgba(0102030f)",
        "group_border_inactive": "rgba(0102030f)",
        "shadow": "0x40010203"
    },
    "hyprlock": {
        "bg": "rgba(1, 2, 3, 0.5)",
        "outer": "rgba(0102030f)",
        "inner": "rgba(0102030f)",
        "font": "rgba(0102030f)",
        "placeholder": "##010203",
        "clock": "rgba(0102030f)",
        "date": "rgba(0102030f)"
    },
    "sddm": {
        "backgroundColor": "#625252",
        "textColor": "#635353",
        "dimTextColor": "#645454",
        "accentColor": "#655555",
        "errorColor": "#665656",
        "popupColor": "#675757"
    },
    "waybar": {
        "cal_fg": "#685858",
        "cal_dim": "#695959",
        "cal_today": "#6a5a5a",
        "agenda_dim": "#6b5b5b",
        "agenda_alert": "#6c5c5c"
    },
    "btop_ramps": {
        "green": [
            "#6d5d5d",
            "#6e5e5e",
            "#6f5f5f"
        ],
        "accent": [
            "#706060",
            "#716161",
            "#726262"
        ],
        "steel": [
            "#736363",
            "#746464",
            "#756565"
        ],
        "used": [
            "#766666",
            "#776767",
            "#786868"
        ],
        "process": [
            "#796969",
            "#7a6a6a",
            "#7b6b6b"
        ]
    },
    "grub": {
        "desktop": "#7c6c6c",
        "message": "#7d6d6d",
        "item": "#7e6e6e",
        "item_selected": "#7f6f6f",
        "bar_bg": "#807070",
        "bar_fg": "#817171"
    },
    "apps": {
        "gtk_theme": "Fixture-dark",
        "gtk_env": "Fixture:dark",
        "icon_theme": "Papirus-Dark",
        "papirus_folders": "blue",
        "qt_scheme": "generated"
    }
}

PNG_1x1 = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c6300010000050001"
)


def png_bytes(width: int, height: int) -> bytes:
    """A PNG header claiming a size; only the first 24 bytes are ever read."""
    return (
        b"\x89PNG\r\n\x1a\n"
        + b"\x00\x00\x00\x0dIHDR"
        + width.to_bytes(4, "big")
        + height.to_bytes(4, "big")
        + b"\x08\x06\x00\x00\x00"
    )


def make_theme(root: Path, name: str = "fixture", **meta) -> Path:
    """Write a complete theme file, with every role the schema requires.

    The colours are sequential rather than meaningful: these tests are about
    whether a value reaches the right key, which a readable palette would make
    harder to tell apart, not about whether it looks good.
    """
    themes = root / "themes"
    themes.mkdir(parents=True, exist_ok=True)
    data = json.loads(json.dumps(FIXTURE_THEME))
    data["meta"] = {**data["meta"], "name": name, **meta}
    path = themes / f"{name}.json"
    path.write_text(json.dumps(data, indent=2) + "\n")
    return path


def make_repo(root: Path, *, wallpapers=("desk.png", "greet.jpg"),
              trailing_nl: bool = True) -> Repo:
    """Write the smallest tree find_repo and Repo will accept."""
    (root / "packages").mkdir(parents=True, exist_ok=True)
    (root / "packages" / "pacman.txt").write_text("hyprland\n")
    (root / "install.sh").write_text(INSTALL_SH)

    (root / "hypr").mkdir(exist_ok=True)
    (root / "hypr" / "hyprland.lua").write_text(HYPRLAND_LUA)

    text = json.dumps(ARCHINSTALL, indent=4, sort_keys=True)
    (root / "user_configuration.json").write_text(text + ("\n" if trailing_nl else ""))

    wall = root / "assets" / "wallpaper"
    wall.mkdir(parents=True, exist_ok=True)
    for name in wallpapers:
        (wall / name).write_bytes(PNG_1x1)

    (root / "webapps").mkdir(exist_ok=True)
    make_theme(root)
    return Repo(root)


class Captured:
    """What a command printed."""

    def __init__(self, out: str, err: str) -> None:
        self.out = out
        self.err = err

    @property
    def all(self) -> str:
        return self.out + self.err


def capture(fn, *args, **kwargs) -> tuple[object, Captured]:
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        result = fn(*args, **kwargs)
    return result, Captured(out.getvalue(), err.getvalue())


class RepoCase(unittest.TestCase):
    """A fresh checkout in a temp dir, plus the three execution modes."""

    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.repo = make_repo(self.tmp / "repo")
        self.root = self.repo.root

        self.live = Context()
        self.no_apply = Context(no_apply=True)
        self.dry = Context(dry_run=True)

    def json(self) -> dict:
        return json.loads(self.repo.archinstall.read_text())

    def lua(self) -> str:
        return self.repo.hyprland_lua.read_text()

    def install_sh(self) -> str:
        return self.repo.install_sh.read_text()

    def theme_file(self, name: str = "fixture") -> dict:
        return json.loads((self.root / "themes" / f"{name}.json").read_text())
