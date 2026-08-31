#!/usr/bin/env python3
"""waybar custom module: today's Google Calendar agenda.

Reads only the cache that `zenix agenda fetch` writes -- never the network --
so the bar is instant and works offline. Prints one line of waybar JSON.

Kept free of the zenix package so waybar spawns a bare interpreter rather than
importing a CLI on every tick.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path

ICON = "\U000f00ed"          # nf-md-calendar_month, as used elsewhere in the bar
MAX_ROWS = 8
STALE_AFTER = 45 * 60        # the timer runs every 5 min; 45 means something broke


def cache_path() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")
    return Path(base) / "zenix" / "agenda.json"


def load() -> dict:
    try:
        return json.loads(cache_path().read_text())
    except FileNotFoundError:
        return {"error": "no agenda cached yet", "events": [], "fetched_at": None}
    except (json.JSONDecodeError, OSError) as exc:
        return {"error": f"unreadable cache: {exc}", "events": [], "fetched_at": None}


def age_seconds(stamp: str | None) -> float | None:
    if not stamp:
        return None
    try:
        then = datetime.fromisoformat(stamp)
    except ValueError:
        return None
    if then.tzinfo is None:
        then = then.replace(tzinfo=timezone.utc)
    return (datetime.now(timezone.utc) - then).total_seconds()


def tooltip(events: list[dict], error: str | None, age: float | None) -> str:
    today = datetime.now().strftime("%A, %d %B")
    today = today[:1].upper() + today[1:]      # some locales give lowercase
    lines = [f"<b>{escape(today)}</b>", ""]

    if error:
        lines.append(f"<span foreground='#98989d'>{escape(error)}</span>")
    elif not events:
        lines.append("<span foreground='#98989d'>No events today</span>")
    else:
        for e in events[:MAX_ROWS]:
            when = escape(e.get("time") or "All day")
            title = escape(e.get("title", ""))
            lines.append(f"<span foreground='#98989d'>{when:>8}</span>   {title}")
        if len(events) > MAX_ROWS:
            more = len(events) - MAX_ROWS
            lines.append(f"<span foreground='#98989d'>+{more} more</span>")

    if age is not None and age > STALE_AFTER:
        lines += ["", f"<span foreground='#ff453a'>last updated {age / 60:.0f} min ago</span>"]

    return "\n".join(lines)


def main() -> int:
    payload = load()
    events = payload.get("events") or []
    error = payload.get("error")
    age = age_seconds(payload.get("fetched_at"))

    if error:
        css = "error"
    elif age is not None and age > STALE_AFTER:
        css = "stale"
    elif events:
        css = "has-events"
    else:
        css = "empty"

    text = f"{ICON}  {len(events)}" if events else ICON

    json.dump({"text": text, "tooltip": tooltip(events, error, age), "class": css},
              sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
