"""Browser web apps, declared as .desktop files under webapps/.

A web app here is a chromeless browser window pinned to one URL. Brave's own
"Install app" flow writes Exec=... --app-id=<hash>, which resolves only against
the PWA registry inside a single Brave profile; this writes --app=<url>, which
depends on nothing and so survives a rebuild.
"""

from __future__ import annotations

import re
import shutil
import struct
from configparser import ConfigParser
from pathlib import Path

from zenix.console import die, dim, header, info, ok, paint, warn
from zenix.context import which

APPLICATIONS = Path.home() / ".local" / "share" / "applications"
HICOLOR = Path.home() / ".local" / "share" / "icons" / "hicolor"
ICON_SIZE = 512  # what install.sh installs into; hicolor/512x512/apps

DEFAULT_BROWSER = "brave"
MARKER = "X-Zenix-WebApp"


def add_parser(sub) -> None:
    p = sub.add_parser("webapp", help="browser web apps (WhatsApp, Gmail, ...)")
    actions = p.add_subparsers(dest="action", required=True)

    actions.add_parser("list", help="list declared web apps").set_defaults(fn=cmd_list)

    a = actions.add_parser("add", help="declare a web app")
    a.add_argument("name", help="slug used for the file, class and icon, e.g. whatsapp")
    a.add_argument("url")
    a.add_argument("--title", help="display name (default: the slug, capitalised)")
    a.add_argument("--icon", help="path to a square PNG, ideally 512x512")
    a.add_argument("--categories", default="Network;",
                   help="freedesktop categories (default: Network;)")
    a.add_argument("--browser", default=DEFAULT_BROWSER,
                   help=f"browser binary (default: {DEFAULT_BROWSER})")
    a.set_defaults(fn=cmd_add)

    r = actions.add_parser("remove", help="remove a declared web app")
    r.add_argument("name")
    r.set_defaults(fn=cmd_remove)


# ------------------------------------------------------------------ helpers --


def webapp_dir(repo) -> Path:
    return repo.root / "webapps"


def entries(repo) -> list[Path]:
    d = webapp_dir(repo)
    return sorted(d.glob("*.desktop")) if d.is_dir() else []


def read_entry(path: Path) -> dict[str, str]:
    parser = ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str  # desktop keys are case-sensitive
    parser.read(path, encoding="utf-8")
    if not parser.has_section("Desktop Entry"):
        return {}
    return dict(parser["Desktop Entry"])


def url_of(entry: dict[str, str]) -> str | None:
    m = re.search(r"--app=(\S+)", entry.get("Exec", ""))
    return m.group(1) if m else None


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    if not slug:
        die(f"{name!r} has no usable characters for a name")
    return slug


def png_size(path: Path) -> tuple[int, int] | None:
    try:
        head = path.read_bytes()[:24]
        if head[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        return struct.unpack(">II", head[16:24])
    except OSError:
        return None


def render(*, title: str, url: str, slug: str, categories: str,
           browser: str, has_icon: bool) -> str:
    # --class sets the Wayland app_id, and StartupWMClass has to match it or the
    # window will not bind to this launcher's icon.
    return "\n".join([
        "[Desktop Entry]",
        "Version=1.0",
        "Type=Application",
        f"Name={title}",
        f"Comment={title} in a chromeless {browser} window",
        f"Exec={browser} --app={url} --class={slug}",
        f"Icon={slug if has_icon else browser}",
        "Terminal=false",
        f"Categories={categories}",
        f"StartupWMClass={slug}",
        f"{MARKER}=true",
        "",
    ])


# ----------------------------------------------------------------- commands --


def cmd_list(ctx, repo, args) -> None:
    header("Web apps in webapps/")
    found = entries(repo)
    if not found:
        info("none declared — add one with `zenix webapp add NAME URL`")
        return

    width = max(len(p.stem) for p in found)
    for path in found:
        entry = read_entry(path)
        installed = (APPLICATIONS / path.name).is_file()
        mark = paint("32", "installed") if installed else paint("2", "not installed")
        print(f"    {path.stem:<{width}}  {url_of(entry) or '?'}")
        print(f"    {'':<{width}}  {entry.get('Name', '?')} · {mark}")


def cmd_add(ctx, repo, args) -> None:
    slug = slugify(args.name)
    title = args.title or slug.replace("-", " ").title()

    if not re.match(r"^https?://", args.url):
        die(f"{args.url!r} must start with http:// or https://")

    dest = webapp_dir(repo) / f"{slug}.desktop"
    if dest.exists():
        die(f"webapps/{slug}.desktop already exists — remove it first")

    header(f"Adding the {title} web app")

    icon_dest = webapp_dir(repo) / "icons" / f"{slug}.png"
    has_icon = False
    if args.icon:
        src = Path(args.icon).expanduser()
        if not src.is_file():
            die(f"no such icon: {args.icon}")
        size = png_size(src)
        if size is None:
            die(f"{src.name}: not a PNG (icons must be PNG)")
        if size != (ICON_SIZE, ICON_SIZE):
            warn(f"{src.name} is {size[0]}x{size[1]}; "
                 f"install.sh files icons under {ICON_SIZE}x{ICON_SIZE}")
        if ctx.dry_run:
            dim(f"$ cp {src} {icon_dest}")
        else:
            icon_dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, icon_dest)
            icon_dest.chmod(0o644)
        has_icon = True
        ok(f"icon stored at webapps/icons/{slug}.png")
    elif icon_dest.is_file():
        has_icon = True
        info(f"reusing the existing webapps/icons/{slug}.png")
    else:
        warn(f"no icon given; falling back to the {args.browser} icon")

    ctx.write(dest, render(title=title, url=args.url, slug=slug,
                           categories=args.categories, browser=args.browser,
                           has_icon=has_icon))
    ok(f"webapps/{slug}.desktop written")

    if not which(args.browser):
        warn(f"{args.browser} is not installed; the launcher will not start until it is")

    if not ctx.apply:
        info("repo updated; the running system was left alone")
        return
    deploy(ctx, dest, icon_dest if has_icon else None)


def cmd_remove(ctx, repo, args) -> None:
    slug = slugify(args.name)
    dest = webapp_dir(repo) / f"{slug}.desktop"
    if not dest.is_file():
        die(f"no such web app: {slug} (try `zenix webapp list`)")

    header(f"Removing the {slug} web app")

    icon = webapp_dir(repo) / "icons" / f"{slug}.png"
    for path in (dest, icon):
        if not path.is_file():
            continue
        if ctx.dry_run:
            dim(f"$ rm {path}")
        else:
            path.unlink()
        ok(f"removed {path.relative_to(dest.parent.parent)}")

    if not ctx.apply:
        info("repo updated; the running system was left alone")
        return

    for path in (APPLICATIONS / f"{slug}.desktop",
                 HICOLOR / f"{ICON_SIZE}x{ICON_SIZE}" / "apps" / f"{slug}.png"):
        if path.is_file():
            if ctx.dry_run:
                dim(f"$ rm {path}")
            else:
                path.unlink()
            ok(f"uninstalled {path}")
    refresh_caches(ctx)


def deploy(ctx, entry: Path, icon: Path | None) -> None:
    ctx.run(["mkdir", "-p", str(APPLICATIONS), str(HICOLOR / f"{ICON_SIZE}x{ICON_SIZE}" / "apps")])
    ctx.run(["install", "-m", "644", str(entry), str(APPLICATIONS / entry.name)])
    if icon is not None:
        ctx.run(["install", "-m", "644", str(icon),
                 str(HICOLOR / f"{ICON_SIZE}x{ICON_SIZE}" / "apps" / icon.name)])
    refresh_caches(ctx)
    ok("installed to ~/.local/share/applications")


def refresh_caches(ctx) -> None:
    """Without these the launcher entry may not appear until the next login."""
    if which("update-desktop-database"):
        ctx.run(["update-desktop-database", str(APPLICATIONS)])
    if which("gtk-update-icon-cache"):
        ctx.run(["gtk-update-icon-cache", "-qtf", str(HICOLOR)])
