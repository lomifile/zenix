"""Desktop and greeter wallpapers."""

from __future__ import annotations

import shutil
from pathlib import Path

from zenix.console import die, dim, header, info, ok, paint, warn
from zenix.context import which
from zenix.repo import GREETER_SUFFIXES, IMAGE_SUFFIXES

SDDM_THEME_DIR = Path("/usr/share/sddm/themes/zenix")

DESKTOP_VAR = "WALLPAPER_NAME"
GREETER_VAR = "GREETER_WALLPAPER_NAME"


def add_parser(sub) -> None:
    p = sub.add_parser("wallpaper", help="desktop and greeter wallpapers")
    actions = p.add_subparsers(dest="action", required=True)

    actions.add_parser("list", help="list assets/wallpaper/").set_defaults(fn=cmd_list)
    actions.add_parser("current", help="show the current choices").set_defaults(fn=cmd_current)

    s = actions.add_parser("set", help="set the wallpaper (name in assets/wallpaper/, or a path)")
    s.add_argument("name")
    s.add_argument("--greeter", action="store_true",
                   help="set the SDDM background instead of the desktop")
    s.set_defaults(fn=cmd_set)


def cmd_list(ctx, repo, args) -> None:
    header("Wallpapers in assets/wallpaper/")
    entries = repo.wallpapers()
    if not entries:
        warn("none found")
        return

    desktop = repo.read_shell_var(DESKTOP_VAR)
    greeter = repo.read_shell_var(GREETER_VAR)
    width = max(len(p.name) for p in entries)

    for p in entries:
        tags = []
        if p.name == desktop:
            tags.append(paint("32", "desktop"))
        if p.name == greeter:
            tags.append(paint("34", "greeter"))
        if p.suffix.lower() not in GREETER_SUFFIXES:
            tags.append(paint("2", "webp: desktop only"))
        size = p.stat().st_size / 1048576
        print(f"    {p.name:<{width}}  {size:6.1f} MB" + ("  " + " ".join(tags) if tags else ""))


def cmd_current(ctx, repo, args) -> None:
    header("Current wallpapers")
    info(f"desktop: {repo.read_shell_var(DESKTOP_VAR)}")
    info(f"greeter: {repo.read_shell_var(GREETER_VAR)}")


def resolve(repo, name: str, *, greeter: bool) -> Path:
    """Accept a name inside assets/wallpaper/, or a path to import."""
    inside = repo.wallpaper_dir / name
    if inside.is_file():
        chosen = inside
    else:
        outside = Path(name).expanduser()
        if not outside.is_file():
            die(f"no such wallpaper: {name} (try `zenix wallpaper list`)")
        chosen = outside

    suffix = chosen.suffix.lower()
    if suffix not in IMAGE_SUFFIXES:
        die(f"{chosen.name}: not an image this setup handles")
    if greeter and suffix not in GREETER_SUFFIXES:
        die(
            f"{chosen.name}: the greeter cannot show webp — Qt needs "
            "qt6-imageformats, which packages/pacman.txt omits"
        )
    return chosen


def import_into_repo(ctx, repo, src: Path) -> str:
    """Copy an outside image in, so a rebuild still has it."""
    if src.parent == repo.wallpaper_dir:
        return src.name

    dest = repo.wallpaper_dir / src.name
    if dest.exists():
        die(f"assets/wallpaper/{src.name} already exists; rename it or use it by name")
    if ctx.dry_run:
        dim(f"$ cp {src} {dest}")
    else:
        repo.wallpaper_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
    ok(f"imported {src.name} into assets/wallpaper/")
    return src.name


def apply_desktop(ctx, repo, name: str) -> None:
    live = Path.home() / "Pictures" / "wallpaper" / name

    if not ctx.dry_run:
        source = repo.wallpaper_dir / name
        if source.is_file() and not live.exists():
            live.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, live)

    conf = Path.home() / ".config" / "hypr" / "hyprpaper.conf"
    ctx.write(conf, f"preload = {live}\nwallpaper = , {live}\nsplash = false\nipc = on\n")
    ok(f"{conf} updated")

    if not which("hyprctl"):
        info("hyprctl unavailable; the change lands at next login")
        return
    ctx.run(["hyprctl", "hyprpaper", "unload", "all"])
    ctx.run(["hyprctl", "hyprpaper", "preload", str(live)])
    ctx.run(["hyprctl", "hyprpaper", "wallpaper", f",{live}"])
    ok("hyprpaper reloaded")


def apply_greeter(ctx, src: Path) -> None:
    if not SDDM_THEME_DIR.is_dir() and not ctx.dry_run:
        info(f"{SDDM_THEME_DIR} not present; run install.sh to deploy the theme")
        return
    # Always landed as background.png: theme.conf names that, and Qt decodes
    # by content rather than extension.
    ctx.run(["sudo", "install", "-m", "644", str(src), str(SDDM_THEME_DIR / "background.png")])
    ok("greeter background installed")


def cmd_set(ctx, repo, args) -> None:
    target = "greeter" if args.greeter else "desktop"
    header(f"Setting the {target} wallpaper")

    src = resolve(repo, args.name, greeter=args.greeter)
    name = import_into_repo(ctx, repo, src)
    if (repo.wallpaper_dir / name).is_file():
        src = repo.wallpaper_dir / name

    var = GREETER_VAR if args.greeter else DESKTOP_VAR
    repo.set_shell_var(ctx, var, name)
    ok(f"install.sh: {var}={name}")

    if not ctx.apply:
        info("repo updated; the running system was left alone")
        return

    if args.greeter:
        apply_greeter(ctx, src)
    else:
        apply_desktop(ctx, repo, name)
