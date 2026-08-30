"""Terminal output, matching install.sh's vocabulary so the two read alike."""

from __future__ import annotations

import sys
from typing import NoReturn

_TTY = sys.stdout.isatty()


def paint(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _TTY else text


def header(msg: str) -> None:
    print(f"\n{paint('34', '==>')} {paint('1', msg)}")


def info(msg: str) -> None:
    print(f"    {msg}")


def ok(msg: str) -> None:
    print(f"    {paint('32', '✓')} {msg}")


def warn(msg: str) -> None:
    print(f"    {paint('33', '!')} {msg}", file=sys.stderr)


def dim(msg: str) -> None:
    print(f"    {paint('2', msg)}")


class ZenixError(Exception):
    """Anything the user can fix; reported without a traceback."""


def die(msg: str) -> NoReturn:
    raise ZenixError(msg)
