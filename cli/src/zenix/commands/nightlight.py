from __future__ import annotations

import json
import signal
import sys
import time as clock
from datetime import datetime
from pathlib import Path

from zenix.config import Config
from zenix.console import header, info, ok, paint, warn
from zenix.context import live_hypr_instance
from zenix.nightlight import (
    Override,
    effective_override,
    night_fraction,
    night_window,
    settings,
    target_temp,
    toggle_override,
)

STATE_RELPATH = Path(".local") / "state" / "zenix" / "nightlight.json"
RAMP_POLL = 10
IDLE_POLL = 60


def add_parser(sub) -> None:
    p = sub.add_parser("nightlight", help="blue-light filter on a schedule (hyprsunset)")
    actions = p.add_subparsers(dest="action", required=True)
    for name, text in (
        ("on", "force warm until the next scheduled change"),
        ("off", "force neutral until the next scheduled change"),
        ("toggle", "flip the current state, or return to the schedule"),
        ("auto", "drop any override and follow the schedule"),
        ("status", "show the schedule and what is applied"),
    ):
        actions.add_parser(name, help=text).set_defaults(fn=cmd_action)
    actions.add_parser("daemon", help="run the scheduler (started by Hyprland)").set_defaults(fn=cmd_daemon)


def now() -> datetime:
    return datetime.now().astimezone()


def state_path() -> Path:
    return Path.home() / STATE_RELPATH


def load_override() -> Override | None:
    path = state_path()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text())
        until = datetime.fromisoformat(data["until"]) if data.get("until") else None
        if data.get("value") not in ("on", "off"):
            return None
        return Override(data["value"], until)
    except (ValueError, KeyError, TypeError, AttributeError):
        return None


def save_override(ctx, override: Override | None) -> None:
    path = state_path()
    if override is None:
        if path.exists():
            if ctx.dry_run:
                info(f"$ rm {path}")
            else:
                path.unlink()
        return
    data = {"value": override.value, "until": override.until.isoformat() if override.until else None}
    ctx.write(path, json.dumps(data) + "\n")


def send(ctx, temp: int, day_temp: int) -> bool:
    signature = live_hypr_instance()
    if signature is None and not ctx.dry_run:
        return False
    env = {"HYPRLAND_INSTANCE_SIGNATURE": signature} if signature else None
    cmd = ["hyprctl", "hyprsunset", "identity"] if temp >= day_temp else \
          ["hyprctl", "hyprsunset", "temperature", str(temp)]
    return ctx.run(cmd, env=env) == 0


def _fmt(moment: datetime | None) -> str:
    return moment.strftime("%a %H:%M") if moment else "until changed"


def cmd_action(ctx, repo, args) -> None:
    cfg = settings(Config.load(repo).get("nightlight", {}))
    moment = now()
    current = effective_override(load_override(), moment)

    if args.action == "status":
        header("Night light")
        window = night_window(cfg, moment)
        info(f"mode       {cfg['mode']}")
        if window:
            info(f"night      {_fmt(window[0])} -> {_fmt(window[1])}")
        else:
            info("night      none scheduled")
        info(f"temps      day {cfg['day_temp']}K, night {cfg['night_temp']}K, "
             f"{cfg['transition_minutes']} min fade")
        if current:
            info(f"override   {paint('33', current.value)} until {_fmt(current.until)}")
        info(f"now        {target_temp(cfg, moment, current)}K")
        return

    if args.action == "auto":
        new = None
    elif args.action == "toggle":
        new = toggle_override(cfg, moment, current)
    else:
        flipped = toggle_override(cfg, moment, None)
        until = flipped.until if flipped and flipped.value == args.action else None
        if until is None:
            window = night_window(cfg, moment)
            if window:
                until = window[1] if moment >= window[0] else window[0]
        new = Override(args.action, until)

    save_override(ctx, new)
    temp = target_temp(cfg, moment, new)
    if new is None:
        ok(f"following the schedule ({temp}K)")
    else:
        ok(f"night light {new.value} until {_fmt(new.until)} ({temp}K)")
    if ctx.apply and not send(ctx, temp, int(cfg["day_temp"])):
        info("hyprsunset did not take it; the daemon will retry")


def tick(ctx, repo, moment: datetime, last: int | None) -> tuple[int | None, int]:
    cfg = settings(Config.load(repo).get("nightlight", {}))
    override = effective_override(load_override(), moment)
    temp = target_temp(cfg, moment, override)
    ramping = override is None and 0 < night_fraction(cfg, moment) < 1
    wait = RAMP_POLL if ramping else IDLE_POLL
    if live_hypr_instance() is None:
        return None, wait
    if temp != last:
        if not send(ctx, temp, int(cfg["day_temp"])):
            return None, RAMP_POLL
    return temp, wait


def cmd_daemon(ctx, repo, args) -> None:
    def stop(signum, frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    last: int | None = None
    try:
        while True:
            try:
                last, wait = tick(ctx, repo, now(), last)
            except Exception as exc:
                warn(f"tick failed: {exc}")
                last, wait = None, IDLE_POLL
            sys.stdout.flush()
            clock.sleep(wait)
    finally:
        cfg = settings(Config.load(repo).get("nightlight", {}))
        send(ctx, int(cfg["day_temp"]), int(cfg["day_temp"]))
