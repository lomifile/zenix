"""Keyboard layout.

Written to both hyprland.lua and user_configuration.json: the first drives the
running desktop, the second drives archinstall on a reinstall. Changing one and
not the other is how they drift apart.
"""

from __future__ import annotations

from pathlib import Path

from zenix.console import die, header, info, ok
from zenix.context import capture, live_hypr_instance, which

XKB_RULES = Path("/usr/share/X11/xkb/rules/base.lst")


def add_parser(sub) -> None:
    p = sub.add_parser("keyboard", help="keyboard layout")
    actions = p.add_subparsers(dest="action", required=True)

    lst = actions.add_parser("list", help="list known layouts")
    lst.add_argument("filter", nargs="?")
    lst.set_defaults(fn=cmd_list)

    actions.add_parser("current", help="show the configured layout").set_defaults(fn=cmd_current)

    s = actions.add_parser("set", help="set the layout")
    s.add_argument("layout")
    s.add_argument("--variant", help='xkb variant, e.g. "dvorak"; pass "" to clear')
    s.set_defaults(fn=cmd_set)


def layouts() -> dict[str, str]:
    """Parse the `! layout` block out of the xkb rules list."""
    if not XKB_RULES.is_file():
        return {}
    found, section = {}, None
    for line in XKB_RULES.read_text(errors="replace").splitlines():
        if line.startswith("!"):
            parts = line[1:].strip().split()
            section = parts[0] if parts else None
            continue
        if section == "layout" and line.strip():
            code, _, desc = line.strip().partition(" ")
            found[code] = desc.strip()
    return found


def cmd_list(ctx, repo, args) -> None:
    known = layouts()
    if not known:
        die(f"{XKB_RULES} missing; is xkeyboard-config installed?")

    needle = (args.filter or "").lower()
    header("Keyboard layouts" + (f" matching {args.filter!r}" if needle else ""))
    hits = [
        (c, d) for c, d in known.items()
        if not needle or needle in c.lower() or needle in d.lower()
    ]
    if not hits:
        info("no match")
        return
    for code, desc in hits:
        print(f"    {code:<12} {desc}")


def cmd_current(ctx, repo, args) -> None:
    data, _ = repo.load_archinstall()
    header("Keyboard")
    info(f"hyprland.lua   {repo.read_lua_field('kb_layout')}"
         f" (variant: {repo.read_lua_field('kb_variant') or '-'})")
    info(f"archinstall    {data.get('locale_config', {}).get('kb_layout')}")
    status = capture(["localectl", "status"]) or ""
    for line in status.splitlines():
        if "Keymap" in line or "Layout" in line:
            info(f"live           {line.strip()}")


def cmd_set(ctx, repo, args) -> None:
    known = layouts()
    if known and args.layout not in known:
        die(f"unknown layout {args.layout!r} (try `zenix keyboard list {args.layout[:2]}`)")

    header(f"Setting the keyboard layout to {args.layout}")

    repo.set_lua_field(ctx, "kb_layout", args.layout, after="kb_layout")
    ok(f"hyprland.lua: kb_layout = {args.layout}")
    if args.variant is not None:
        repo.set_lua_field(ctx, "kb_variant", args.variant, after="kb_layout")
        ok(f"hyprland.lua: kb_variant = {args.variant or '(cleared)'}")

    data, trailing_nl = repo.load_archinstall()
    data.setdefault("locale_config", {})["kb_layout"] = args.layout
    repo.save_archinstall(ctx, data, trailing_nl)
    ok(f"user_configuration.json: locale_config.kb_layout={args.layout}")

    if not ctx.apply:
        info("repo updated; the running system was left alone")
        return

    signature = live_hypr_instance()
    if which("hyprctl") and (signature or ctx.dry_run):
        env = {"HYPRLAND_INSTANCE_SIGNATURE": signature} if signature else None
        ctx.run(["hyprctl", "keyword", "input:kb_layout", args.layout], env=env)
        if args.variant is not None:
            ctx.run(["hyprctl", "keyword", "input:kb_variant", args.variant], env=env)
        ok("hyprland reloaded")

    # Covers the TTY and any X11 session started later.
    ctx.run(["sudo", "localectl", "set-x11-keymap", args.layout, "", args.variant or ""])
    ctx.run(["sudo", "localectl", "set-keymap", args.layout])
    ok("localectl updated")
