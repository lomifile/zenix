"""One screen showing what is configured where, repo against live."""

from __future__ import annotations

from zenix import theme as gen
from zenix.commands.theme import THEME_VAR
from zenix.commands.timezone import live_zone
from zenix.commands.wallpaper import DESKTOP_VAR, GREETER_VAR, SDDM_THEME_DIR
from zenix.console import header, info, paint


def add_parser(sub) -> None:
    sub.add_parser("status", help="show what is configured where").set_defaults(fn=cmd_status)


def _row(label: str, value: object, note: str = "") -> None:
    print(f"    {label:<13}{value}{note}")


def cmd_status(ctx, repo, args) -> None:
    data, _ = repo.load_archinstall()

    header("zenix")
    info(f"repo: {repo.root}")

    print(f"\n  {paint('1', 'wallpaper')}")
    for label, var in (("desktop", DESKTOP_VAR), ("greeter", GREETER_VAR)):
        name = repo.read_shell_var(var)
        missing = "" if (repo.wallpaper_dir / (name or "")).is_file() else paint("31", "  MISSING")
        _row(label, name, missing)
    deployed = SDDM_THEME_DIR / "background.png"
    _row("greeter@", "installed" if deployed.is_file() else "not deployed", f"  ({deployed})")

    print(f"\n  {paint('1', 'theme')}")
    name = repo.read_shell_var(THEME_VAR)
    _row("name", name or paint("31", "unset"))
    if name in gen.names(repo):
        t = gen.load(repo, name)
        files = gen.plan(t, repo)
        fresh = sum(1 for p, text in files.items() if p.is_file() and p.read_text() == text)
        drift = "" if fresh == len(files) else paint("33", "  run `zenix theme set`")
        _row("palette", f"{t.label} · {t.meta['background']}")
        _row("surfaces", f"{fresh}/{len(files)} in sync", drift)
    elif name:
        _row("palette", paint("31", f"themes/{name}.json is missing"))
    conf = SDDM_THEME_DIR / "theme.conf"
    _row("greeter@", "installed" if conf.is_file() else "not deployed", f"  ({conf})")

    print(f"\n  {paint('1', 'keyboard')}")
    _row("hyprland", repo.read_lua_field("kb_layout"),
         f"  (variant: {repo.read_lua_field('kb_variant') or '-'})")
    _row("archinstall", data.get("locale_config", {}).get("kb_layout"))

    print(f"\n  {paint('1', 'timezone')}")
    _row("archinstall", data.get("timezone"))
    _row("live", live_zone() or "unknown")
    print()
