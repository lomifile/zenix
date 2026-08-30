"""Execution mode plus the two side effects every command needs."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from zenix.console import dim, warn


def which(name: str) -> bool:
    return shutil.which(name) is not None


def capture(cmd: list[str]) -> str | None:
    """Run a command for its output, returning None if it is unavailable."""
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except (FileNotFoundError, PermissionError):
        return None
    return proc.stdout.strip() if proc.returncode == 0 else None


class Context:
    """Carries --dry-run/--no-apply so commands need not thread them around."""

    def __init__(self, *, dry_run: bool = False, no_apply: bool = False) -> None:
        self.dry_run = dry_run
        # A dry run implies no apply; the reverse does not hold.
        self.apply = not no_apply and not dry_run

    def run(self, cmd: list[str]) -> int:
        if self.dry_run:
            dim("$ " + " ".join(cmd))
            return 0
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True)
        except FileNotFoundError:
            warn(f"{cmd[0]} not found; skipping")
            return 127
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip().splitlines()
            warn(f"{' '.join(cmd)} failed: {detail[0] if detail else proc.returncode}")
        return proc.returncode

    def write(self, path: Path, text: str) -> None:
        if self.dry_run:
            dim(f"$ write {path}")
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
