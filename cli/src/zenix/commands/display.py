from __future__ import annotations

from pathlib import Path

from zenix.config import Config
from zenix.console import dim, header, info, ok, paint, warn
from zenix.context import capture, live_hypr_instance, which
from zenix.display import parse_monitors, pending, plan_layout, saved_lua, to_lua

SAVED_RELPATH = Path(".config") / "zenix" / "display.lua"


def add_parser(sub) -> None:
    p = sub.add_parser("display", help="monitors: external first, laptop as fallback")
    actions = p.add_subparsers(dest="action", required=True)

    r = actions.add_parser("refresh", help="re-apply the monitor layout")
    r.add_argument("--auto", action="store_true",
                   help="only apply what differs (used by the hotplug hook)")
    r.set_defaults(fn=cmd_refresh)

    actions.add_parser("list", help="list outputs and what refresh would do").set_defaults(fn=cmd_list)


def saved_path() -> Path:
    return Path.home() / SAVED_RELPATH


def is_running(name: str) -> bool:
    return which("pgrep") and capture(["pgrep", "-x", name]) is not None


def _snapshot(repo):
    cfg = Config.load(repo).get("display", {})
    signature = live_hypr_instance()
    env = {"HYPRLAND_INSTANCE_SIGNATURE": signature} if signature else None
    raw = capture(["hyprctl", "monitors", "all", "-j"], env=env) if signature else None
    return cfg, env, raw


def cmd_list(ctx, repo, args) -> None:
    cfg, _, raw = _snapshot(repo)
    if raw is None:
        warn("hyprland is not running; nothing to list")
        return
    monitors = parse_monitors(raw)
    rules = {r["output"]: r for r in plan_layout(monitors, cfg)}
    header("Outputs")
    width = max((len(m.name) for m in monitors), default=0)
    for m in monitors:
        role = "laptop" if m.name == cfg.get("laptop", "eDP-1") else "external"
        state = paint("2", "off") if m.disabled else paint("32", "on")
        want = "off" if rules.get(m.name, {}).get("disabled") else "on"
        print(f"    {m.name:<{width}}  {role:<8}  {state}  scale {m.scale:g}  -> {want}  {paint('2', m.description)}")


def cmd_refresh(ctx, repo, args) -> None:
    cfg, env, raw = _snapshot(repo)
    if raw is None:
        warn("hyprland is not running; nothing to refresh")
        return

    monitors = parse_monitors(raw)
    rules = plan_layout(monitors, cfg)
    todo = pending(rules, monitors, force=not args.auto)

    if not args.auto:
        header("Refreshing displays")
    for rule in todo:
        ctx.run(["hyprctl", "eval", to_lua(rule)], env=env)
        if not args.auto:
            state = "off" if rule.get("disabled") else "on"
            ok(f"{rule['output']} {state}")

    path = saved_path()
    text = saved_lua(rules, cfg.get("laptop", "eDP-1"))
    if not path.is_file() or path.read_text() != text:
        ctx.write(path, text)

    if not is_running("hyprpaper"):
        ctx.run(["hyprctl", "eval", 'hl.exec_cmd("hyprpaper")'], env=env)
        if not args.auto:
            ok("hyprpaper restarted")

    if args.auto:
        return

    ctx.run(["pkill", "-SIGUSR2", "waybar"])
    active = [r["output"] for r in rules if not r.get("disabled")]
    summary = ", ".join(active) or "no outputs"
    ctx.run(["notify-send", "-a", "zenix", "Display refreshed", summary])
    info(f"active: {summary}")
    if not todo:
        dim("layout was already correct")
