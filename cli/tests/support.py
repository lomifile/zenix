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
"""

HYPRLAND_LUA = """return {
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
