"""Reading the agenda out of gcalcli.

Kept free of GTK so the parsing can be exercised without a display.
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass

TIMEOUT_SECONDS = 10

# gcalcli --tsv columns: start_date, start_time, end_date, end_time, title
_TSV_MIN_FIELDS = 5
_TITLE_INDEX = 4
_START_TIME_INDEX = 1


@dataclass(frozen=True)
class Event:
    time: str
    title: str

    @property
    def when(self) -> str:
        return self.time or "All Day"


class AgendaError(Exception):
    """Something the popup should render as a message instead of events."""


class GcalcliMissing(AgendaError):
    pass


class AuthRequired(AgendaError):
    pass


class AgendaTimeout(AgendaError):
    pass


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


def fetch(span: tuple[str, str] = ("today", "tomorrow")) -> list[Event]:
    """Today's agenda. Raises AgendaError subclasses the caller can render."""
    try:
        result = subprocess.run(
            ["gcalcli", "agenda", span[0], span[1], "--tsv"],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
        )
    except FileNotFoundError as exc:
        raise GcalcliMissing("gcalcli is not installed.") from exc
    except subprocess.TimeoutExpired as exc:
        raise AgendaTimeout("Timed out talking to Google Calendar.") from exc
    except OSError as exc:
        raise AgendaError("Could not run gcalcli.") from exc

    if result.returncode != 0:
        # gcalcli exits non-zero before the OAuth handshake has been done.
        raise AuthRequired("Authentication required — run 'gcalcli init'.")

    return parse_tsv(result.stdout)
