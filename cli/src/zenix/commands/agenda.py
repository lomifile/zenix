"""The Google Calendar agenda behind the waybar module."""

from __future__ import annotations

from zenix import agenda as core
from zenix.console import header, info, ok, warn


def add_parser(sub) -> None:
    p = sub.add_parser("agenda", help="Google Calendar agenda cache")
    actions = p.add_subparsers(dest="action", required=True)

    f = actions.add_parser("fetch", help="refresh the cache (run by the systemd timer)")
    f.set_defaults(fn=cmd_fetch)

    actions.add_parser("show", help="print the cached agenda").set_defaults(fn=cmd_show)
    actions.add_parser("path", help="print the cache path").set_defaults(fn=cmd_path)


def cmd_fetch(ctx, repo, args) -> None:
    header("Refreshing the agenda cache")

    if ctx.dry_run:
        info(f"would fetch and write {core.cache_path()}")
        return

    events, error = core.fetch()
    path = core.write_cache(events, error)

    # The cache is written either way: the bar shows the error rather than
    # going blank, and a transient failure does not wipe a good agenda.
    if error:
        warn(f"{error} (cached, so the bar can show it)")
    else:
        ok(f"{len(events)} event(s) -> {path}")


def cmd_show(ctx, repo, args) -> None:
    payload = core.read_cache()
    header("Cached agenda")

    age = core.cache_age_seconds(payload)
    info(f"fetched: {payload.get('fetched_at') or 'never'}"
         + (f"  ({age / 60:.0f} min ago)" if age is not None else ""))

    if payload.get("error"):
        warn(payload["error"])
    events = payload.get("events", [])
    if not events:
        info("no events")
        return
    for e in events:
        info(f"  {e.get('time') or 'All day':<8} {e.get('title', '')}")


def cmd_path(ctx, repo, args) -> None:
    print(core.cache_path())
