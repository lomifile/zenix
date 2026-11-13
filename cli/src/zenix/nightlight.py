from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone, tzinfo

DEFAULTS = {
    "mode": "custom",
    "day_temp": 6500,
    "night_temp": 4500,
    "start": "20:00",
    "end": "07:00",
    "transition_minutes": 30,
    "latitude": 0.0,
    "longitude": 0.0,
}

ZENITH = 90.833


@dataclass(frozen=True)
class Override:
    value: str
    until: datetime | None


def settings(cfg: dict | None) -> dict:
    return {**DEFAULTS, **(cfg or {})}


def parse_hhmm(text: str, fallback: str) -> time:
    for candidate in (text, fallback):
        try:
            hh, mm = str(candidate).split(":")
            return time(int(hh), int(mm))
        except (ValueError, TypeError):
            continue
    return time(0, 0)


def _sun_event_utc(day: date, lat: float, lon: float, rising: bool) -> float | None:
    rad, deg = math.radians, math.degrees
    n = day.timetuple().tm_yday
    lng_hour = lon / 15
    t = n + ((6 if rising else 18) - lng_hour) / 24
    m = 0.9856 * t - 3.289
    l = (m + 1.916 * math.sin(rad(m)) + 0.020 * math.sin(rad(2 * m)) + 282.634) % 360
    ra = deg(math.atan(0.91764 * math.tan(rad(l)))) % 360
    ra += (math.floor(l / 90) - math.floor(ra / 90)) * 90
    ra /= 15
    sin_dec = 0.39782 * math.sin(rad(l))
    cos_dec = math.cos(math.asin(sin_dec))
    cos_h = (math.cos(rad(ZENITH)) - sin_dec * math.sin(rad(lat))) / (cos_dec * math.cos(rad(lat)))
    if cos_h > 1 or cos_h < -1:
        return None
    h = deg(math.acos(cos_h))
    h = (360 - h if rising else h) / 15
    local_mean = h + ra - 0.06571 * t - 6.622
    return (local_mean - lng_hour) % 24


def _on_day(day: date, utc_hours: float, tz: tzinfo) -> datetime:
    base = datetime(day.year, day.month, day.day, tzinfo=timezone.utc)
    moment = (base + timedelta(hours=utc_hours)).astimezone(tz)
    if moment.date() > day:
        moment -= timedelta(days=1)
    elif moment.date() < day:
        moment += timedelta(days=1)
    return moment


def sun_times(day: date, lat: float, lon: float, tz: tzinfo) -> tuple[datetime, datetime] | None:
    rise = _sun_event_utc(day, lat, lon, rising=True)
    sets = _sun_event_utc(day, lat, lon, rising=False)
    if rise is None or sets is None:
        return None
    return _on_day(day, rise, tz), _on_day(day, sets, tz)


def _candidates(cfg: dict, now: datetime):
    tz = now.tzinfo
    today = now.date()
    for offset in (-1, 0, 1):
        day = today + timedelta(days=offset)
        if cfg["mode"] == "sun":
            tonight = sun_times(day, float(cfg["latitude"]), float(cfg["longitude"]), tz)
            tomorrow = sun_times(day + timedelta(days=1), float(cfg["latitude"]), float(cfg["longitude"]), tz)
            if tonight is None or tomorrow is None:
                continue
            yield tonight[1], tomorrow[0]
        else:
            start_t = parse_hhmm(cfg["start"], DEFAULTS["start"])
            end_t = parse_hhmm(cfg["end"], DEFAULTS["end"])
            start = datetime.combine(day, start_t, tzinfo=tz)
            end = datetime.combine(day, end_t, tzinfo=tz)
            if end <= start:
                end += timedelta(days=1)
            yield start, end


def night_window(cfg: dict, now: datetime) -> tuple[datetime, datetime] | None:
    cfg = settings(cfg)
    if cfg["mode"] not in ("custom", "sun"):
        return None
    upcoming = sorted(w for w in _candidates(cfg, now) if w[1] > now)
    return upcoming[0] if upcoming else None


def night_fraction(cfg: dict, now: datetime) -> float:
    cfg = settings(cfg)
    window = night_window(cfg, now)
    if window is None:
        return 0.0
    start, end = window
    if now < start:
        return 0.0
    ramp = timedelta(minutes=max(0, int(cfg["transition_minutes"])))
    if ramp == timedelta(0):
        return 1.0
    return max(0.0, min(1.0, (now - start) / ramp, (end - now) / ramp))


def effective_override(override: Override | None, now: datetime) -> Override | None:
    if override is None:
        return None
    if override.until is not None and now >= override.until:
        return None
    return override


def target_temp(cfg: dict, now: datetime, override: Override | None = None) -> int:
    cfg = settings(cfg)
    day, night = int(cfg["day_temp"]), int(cfg["night_temp"])
    active = effective_override(override, now)
    if active is not None:
        return night if active.value == "on" else day
    fraction = night_fraction(cfg, now)
    return int(round(day - (day - night) * fraction))


def next_boundary(cfg: dict, now: datetime) -> datetime | None:
    window = night_window(cfg, now)
    if window is None:
        return None
    start, end = window
    return end if now >= start else start


def toggle_override(cfg: dict, now: datetime, current: Override | None) -> Override | None:
    if effective_override(current, now) is not None:
        return None
    if night_fraction(cfg, now) > 0:
        return Override("off", next_boundary(cfg, now))
    until = next_boundary(cfg, now)
    if until is not None:
        until += timedelta(minutes=max(0, int(settings(cfg)["transition_minutes"])))
    return Override("on", until)
