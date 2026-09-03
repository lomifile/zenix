"""Tests for the zenix CLI.

Stdlib unittest, no dependencies: the package itself declares none, and the
machine install.sh runs this on has nothing but the base interpreter.

    cd cli && python -m unittest discover -s tests -t .
"""

import sys
from pathlib import Path

_SRC = str(Path(__file__).resolve().parent.parent / "src")
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)
