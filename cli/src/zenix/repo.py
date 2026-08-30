"""Locating the zenix checkout and editing the files inside it.

Installed into a venv, the package can no longer find the repo relative to its
own __file__, so the location has to be discovered or supplied.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

from zenix.console import die

# Enough to identify a zenix checkout without matching an arbitrary git repo.
MARKERS = ("install.sh", "packages/pacman.txt")

# Qt has no webp decoder without qt6-imageformats, which packages/pacman.txt
# omits, so the greeter is limited to what it can actually display.
GREETER_SUFFIXES = frozenset({".png", ".jpg", ".jpeg"})
IMAGE_SUFFIXES = GREETER_SUFFIXES | {".webp"}


def _looks_like_repo(path: Path) -> bool:
    return all((path / m).exists() for m in MARKERS)


def find_repo(explicit: str | None = None) -> Path:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit).expanduser())
    if env := os.environ.get("ZENIX_REPO"):
        candidates.append(Path(env).expanduser())

    cwd = Path.cwd().resolve()
    candidates.extend([cwd, *cwd.parents])
    candidates.append(Path.home() / "build" / "zenix")

    for c in candidates:
        if _looks_like_repo(c):
            return c

    if explicit:
        die(f"{explicit} is not a zenix checkout (no install.sh + packages/pacman.txt)")
    die(
        "cannot find the zenix repo — run this from inside it, "
        "or pass --repo PATH, or set ZENIX_REPO"
    )


class Repo:
    """Typed access to the handful of files the CLI edits."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.install_sh = root / "install.sh"
        self.hyprland_lua = root / "hypr" / "hyprland.lua"
        self.archinstall = root / "user_configuration.json"
        self.wallpaper_dir = root / "assets" / "wallpaper"

    # -- assets ------------------------------------------------------------

    def wallpapers(self) -> list[Path]:
        if not self.wallpaper_dir.is_dir():
            return []
        return sorted(
            p
            for p in self.wallpaper_dir.iterdir()
            if p.is_file() and p.suffix.lower() in IMAGE_SUFFIXES
        )

    # -- install.sh --------------------------------------------------------

    def read_shell_var(self, name: str) -> str | None:
        pat = re.compile(rf'^{re.escape(name)}="([^"]*)"', re.M)
        m = pat.search(self.install_sh.read_text())
        return m.group(1) if m else None

    def set_shell_var(self, ctx, name: str, value: str) -> None:
        text = self.install_sh.read_text()
        pat = re.compile(rf'^({re.escape(name)}=)"[^"]*"', re.M)
        if not pat.search(text):
            die(f"{name}= not found in install.sh; the CLI and the script are out of sync")
        ctx.write(self.install_sh, pat.sub(rf'\g<1>"{value}"', text, count=1))

    # -- hyprland.lua ------------------------------------------------------

    def read_lua_field(self, field: str) -> str | None:
        m = re.search(rf'\b{re.escape(field)}\s*=\s*"([^"]*)"', self.hyprland_lua.read_text())
        return m.group(1) if m else None

    def set_lua_field(self, ctx, field: str, value: str, *, after: str) -> None:
        """Set a field in hyprland.lua, inserting it after `after` if absent."""
        text = self.hyprland_lua.read_text()
        pat = re.compile(rf'(\b{re.escape(field)}\s*=\s*)"[^"]*"')

        if pat.search(text):
            new = pat.sub(rf'\g<1>"{value}"', text, count=1)
        else:
            anchor = re.compile(rf'^(\s*){re.escape(after)}\s*=\s*"[^"]*",$', re.M)
            m = anchor.search(text)
            if not m:
                die(f"cannot place {field}: no {after} line in hyprland.lua")
            new = text[: m.end()] + f'\n{m.group(1)}{field} = "{value}",' + text[m.end() :]

        ctx.write(self.hyprland_lua, new)

    # -- user_configuration.json -------------------------------------------

    def load_archinstall(self) -> tuple[dict, bool]:
        raw = self.archinstall.read_text()
        return json.loads(raw), raw.endswith("\n")

    def save_archinstall(self, ctx, data: dict, trailing_nl: bool) -> None:
        # archinstall writes 4-space indented, key-sorted JSON; matching that
        # keeps the diff to the line that actually changed.
        text = json.dumps(data, indent=4, sort_keys=True)
        ctx.write(self.archinstall, text + ("\n" if trailing_nl else ""))
