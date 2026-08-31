"""Google Calendar agenda: fetching, caching, and reading the cache.

Fetching and display are deliberately separated. The waybar module reads a
cache file and never touches the network, so hovering the bar is instant and
works offline; a systemd user timer does the slow part out of band.
"""

from __future__ import annotations

import json
import os
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

TIMEOUT_SECONDS = 20

# gcalcli --tsv columns: start_date, start_time, end_date, end_time, title
_TSV_MIN_FIELDS = 5
_START_TIME_INDEX = 1
_TITLE_INDEX = 4


def cache_path() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")
    return Path(base) / "zenix" / "agenda.json"


@dataclass(frozen=True)
class Event:
    time: str
    title: str

    @property
    def when(self) -> str:
        return self.time or "All day"


def parse_tsv(text: str) -> list[Event]:
    events = []
    for line in text.strip().splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) >= _TSV_MIN_FIELDS:
            events.append(Event(time=parts[_START_TIME_INDEX].strip(),
                                title=parts[_TITLE_INDEX].strip()))
    return events


def fetch(span: tuple[str, str] = ("today", "tomorrow")) -> tuple[list[Event], str | None]:
    """Return (events, error). Never raises — the caller caches either way."""
    try:
        result = subprocess.run(
            ["gcalcli", "agenda", span[0], span[1], "--tsv"],
            capture_output=True, text=True, timeout=TIMEOUT_SECONDS,
        )
    except FileNotFoundError:
        return [], "gcalcli is not installed"
    except subprocess.TimeoutExpired:
        return [], "gcalcli timed out"
    except OSError as exc:
        return [], f"could not run gcalcli: {exc}"

    if result.returncode != 0:
        # gcalcli exits non-zero before the OAuth handshake has been done.
        return [], "not authenticated — run 'gcalcli init'"

    return parse_tsv(result.stdout), None


def write_cache(events: list[Event], error: str | None) -> Path:
    path = cache_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "error": error,
        "events": [asdict(e) for e in events],
    }
    # Written via a temporary file so waybar can never read a half-written one.
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2) + "\n")
    tmp.replace(path)
    return path


def read_cache() -> dict:
    """The cache as a dict. A missing or corrupt file is reported, not raised."""
    path = cache_path()
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {"fetched_at": None, "error": "no agenda cached yet", "events": []}
    except (json.JSONDecodeError, OSError) as exc:
        return {"fetched_at": None, "error": f"unreadable cache: {exc}", "events": []}


def cache_age_seconds(payload: dict) -> float | None:
    stamp = payload.get("fetched_at")
    if not stamp:
        return None
    try:
        then = datetime.fromisoformat(stamp)
    except ValueError:
        return None
    if then.tzinfo is None:
        then = then.replace(tzinfo=timezone.utc)
    return (datetime.now(timezone.utc) - then).total_seconds()
