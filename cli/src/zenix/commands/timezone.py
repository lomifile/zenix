"""System timezone."""

from __future__ import annotations

from zenix.console import die, header, info, ok
from zenix.context import capture


def add_parser(sub) -> None:
    p = sub.add_parser("timezone", help="system timezone")
    actions = p.add_subparsers(dest="action", required=True)

    lst = actions.add_parser("list", help="list timezones")
    lst.add_argument("filter", nargs="?")
    lst.set_defaults(fn=cmd_list)

    actions.add_parser("current", help="show the configured timezone").set_defaults(fn=cmd_current)

    s = actions.add_parser("set", help="set the timezone")
    s.add_argument("zone")
    s.set_defaults(fn=cmd_set)


def zones() -> list[str]:
    try:
        from zoneinfo import available_timezones

        return sorted(available_timezones())
    except Exception:
        # No tzdata: fall back to systemd's view rather than refusing to run.
        out = capture(["timedatectl", "list-timezones"])
        return out.splitlines() if out else []


def live_zone() -> str | None:
    return capture(["timedatectl", "show", "-p", "Timezone", "--value"])


def cmd_list(ctx, repo, args) -> None:
    needle = (args.filter or "").lower()
    header("Timezones" + (f" matching {args.filter!r}" if needle else ""))
    hits = [z for z in zones() if needle in z.lower()]
    if not hits:
        info("no match")
        return
    for z in hits:
        print(f"    {z}")


def cmd_current(ctx, repo, args) -> None:
    data, _ = repo.load_archinstall()
    header("Timezone")
    info(f"archinstall    {data.get('timezone')}")
    info(f"live           {live_zone() or 'unknown'}")


def cmd_set(ctx, repo, args) -> None:
    known = zones()
    if known and args.zone not in known:
        hint = args.zone.split("/")[0]
        die(f"unknown timezone {args.zone!r} (try `zenix timezone list {hint}`)")

    header(f"Setting the timezone to {args.zone}")
    data, trailing_nl = repo.load_archinstall()
    data["timezone"] = args.zone
    repo.save_archinstall(ctx, data, trailing_nl)
    ok(f"user_configuration.json: timezone={args.zone}")

    if not ctx.apply:
        info("repo updated; the running system was left alone")
        return
    ctx.run(["sudo", "timedatectl", "set-timezone", args.zone])
    ok("system clock updated")
