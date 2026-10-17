"""The colour theme every surface is generated from."""

from __future__ import annotations

from pathlib import Path

from zenix import theme as gen
from zenix.console import die, dim, header, info, ok, paint, warn
from zenix.context import capture, live_hypr_instance, which

THEME_VAR = "THEME_NAME"

SDDM_THEME_DIR = Path("/usr/share/sddm/themes/zenix")
TMUX_PLUGIN_THEME = Path("tmux/plugins/tokyo-night-tmux/src/themes.sh")

GSETTINGS_IFACE = "org.gnome.desktop.interface"


def add_parser(sub) -> None:
    p = sub.add_parser("theme", help="the colour theme for every surface")
    actions = p.add_subparsers(dest="action", required=True)

    actions.add_parser("list", help="list themes/").set_defaults(fn=cmd_list)
    actions.add_parser(
        "current", help="show the selection, and check every surface agrees"
    ).set_defaults(fn=cmd_current)

    show = actions.add_parser("show", help="print a theme's resolved palette")
    show.add_argument("name")
    show.set_defaults(fn=cmd_show)

    s = actions.add_parser("set", help="switch themes (a name in themes/)")
    s.add_argument("name")
    s.set_defaults(fn=cmd_set)


# -- reading -----------------------------------------------------------------


def config_dir() -> Path:
    return Path.home() / ".config"


def selected(repo) -> str | None:
    return repo.read_shell_var(THEME_VAR)


def cmd_list(ctx, repo, args) -> None:
    header("Themes in themes/")
    found = gen.names(repo)
    if not found:
        warn("none found")
        return

    current = selected(repo)
    width = max(len(n) for n in found)
    for name in found:
        t = gen.load(repo, name)
        tag = "  " + paint("32", "current") if name == current else ""
        print(f"    {name:<{width}}  {t.label}{tag}")


def cmd_show(ctx, repo, args) -> None:
    t = gen.load(repo, args.name)
    header(f"{t.name} — {t.label}")
    for section in t.SECTIONS:
        values = getattr(t, section)
        if not isinstance(values, dict):
            continue
        print(f"\n  {paint('1', section)}")
        for key, value in values.items():
            if key.startswith("_"):
                continue
            print(f"    {key:<22} {value}")


# Each row of `zenix theme current`: the file that actually drives a surface,
# and how to read the theme name out of it. A surface that disagrees with
# THEME_NAME is drift -- a half-finished `theme set`, a `git checkout`, or btop
# having rewritten its own config -- and is worth naming rather than hiding.
def surface_selectors(repo, t) -> list[tuple[str, str | None, str]]:
    def read(path: Path, needle: str) -> str | None:
        if not path.is_file():
            return None
        for line in path.read_text().splitlines():
            if line.startswith(needle):
                return line.split("=", 1)[1].strip().strip('"')
        return None

    qt = read(repo.root / "qt6ct" / "qt6ct.conf", "color_scheme_path")
    return [
        ("ghostty", read(repo.root / "ghostty" / "config.ghostty", "theme "), t.name),
        ("btop", read(repo.root / "btop" / "btop.conf", "color_theme "), t.name),
        # Not always the theme's own name: a theme may point at one of qt6ct's
        # stock schemes instead of shipping a palette of its own.
        ("qt6ct", qt, gen.qt_scheme_path(t)),
    ]


def cmd_current(ctx, repo, args) -> None:
    header("Current theme")
    name = selected(repo)
    if not name:
        warn(f"{THEME_VAR} is not set in install.sh")
        return

    t = gen.load(repo, name)
    info(f"{paint('1', name)}  {t.label}")

    drift = 0
    for surface, value, expected in surface_selectors(repo, t):
        if value is None:
            info(f"{surface:<12} not configured")
        elif value == expected:
            ok(f"{surface:<12} {value}")
        else:
            warn(f"{surface:<12} {value}  (expected {expected})")
            drift += 1

    # The generated files are the other half of the answer: a selector can name
    # the right theme while the files it selects are stale.
    stale = [
        path.relative_to(repo.root)
        for path, text in gen.plan(t, repo).items()
        if not path.is_file() or path.read_text() != text
    ]
    if stale:
        warn(f"{len(stale)} generated file(s) out of date — run `zenix theme set {name}`")
        for rel in stale:
            info(f"  {rel}")
    else:
        ok("generated files in sync")

    live = capture(["gsettings", "get", GSETTINGS_IFACE, "gtk-theme"])
    if live:
        info(f"live gtk theme  {live.strip().strip(chr(39))}")
    if drift:
        warn(f"{drift} surface(s) disagree with {THEME_VAR}")


# -- applying ----------------------------------------------------------------


def apply_tmux(ctx, repo) -> None:
    """themes.sh is installed over the plugin's own copy, not linked.

    tokyo-night-tmux ships four hardcoded palettes and no hook for a custom
    one, so install.sh overwrites the file tpm cloned -- and a plugin update
    restores it, which is why this reapplies rather than being done once.
    """
    dest = config_dir() / TMUX_PLUGIN_THEME
    if not dest.parent.is_dir() and not ctx.dry_run:
        info("tokyo-night-tmux not installed; tmux theme not applied")
        return

    ctx.run(["install", "-m", "644", str(repo.root / "tmux" / "themes.sh"), str(dest)])
    if not which("tmux") or not capture(["tmux", "list-sessions"]):
        info("no tmux server running; the theme lands on the next one")
        return
    ctx.run(["tmux", "source-file", str(config_dir() / "tmux" / "tmux.conf")])
    ctx.run(["tmux", "refresh-client", "-S"])
    ok("tmux reloaded")


def apply_qt6ct(ctx, repo) -> None:
    """Write the live qt6ct.conf with the placeholder expanded.

    qt6ct resolves `color_scheme_path` as an absolute path and expands nothing,
    so the repo copy carries __HOME__ and the real path is only ever written
    here and by install.sh.
    """
    src = repo.root / "qt6ct" / "qt6ct.conf"
    if not src.is_file():
        return
    dest = config_dir() / "qt6ct" / "qt6ct.conf"

    # Older installs linked this file; a link would send the placeholder
    # straight back into the repo.
    if dest.is_symlink():
        if ctx.dry_run:
            dim(f"$ rm {dest}")
        else:
            dest.unlink()

    ctx.write(dest, src.read_text().replace(gen.HOME_PLACEHOLDER, str(Path.home())))
    ok(f"{dest} written")


def apply_gsettings(ctx, t) -> None:
    if not which("gsettings"):
        info("gsettings unavailable; GTK apps follow at next login")
        return
    scheme = "prefer-dark" if t.is_dark else "prefer-light"
    for key, value in (
        ("color-scheme", scheme),
        ("gtk-theme", t.apps["gtk_theme"]),
        ("icon-theme", t.apps["icon_theme"]),
    ):
        ctx.run(["gsettings", "set", GSETTINGS_IFACE, key, value])
    ok("gsettings updated")
    # GTK_THEME is an environment variable set in hyprland.lua, and it
    # overrides gsettings for GTK3. Saying "GTK apps are themed" here would be
    # a quarter true.
    info("GTK3 reads GTK_THEME from the session, so it changes at next login")


def apply_papirus(ctx, t) -> None:
    folder = t.apps["papirus_folders"]
    if not folder:
        return
    if not which("papirus-folders"):
        info("papirus-folders not installed; folder icons unchanged")
        return
    # Folder colour is global system state under /usr/share/icons, not a
    # per-theme file, which is why every theme names one explicitly: switching
    # back has to put it back.
    ctx.run(["sudo", "papirus-folders", "-C", folder, "-t", t.apps["icon_theme"]])
    ok(f"papirus folders set to {folder}")


def apply_waybar(ctx) -> None:
    if not which("pkill"):
        return
    if ctx.run(["pkill", "-SIGUSR2", "waybar"]) == 0:
        ok("waybar reloaded")
    else:
        info("waybar is not running; the style lands when it starts")


def apply_hyprland(ctx) -> None:
    if not which("hyprctl"):
        info("hyprctl unavailable; borders land at next login")
        return
    signature = live_hypr_instance()
    if signature is None and not ctx.dry_run:
        info("hyprland is not running; borders land at next login")
        return
    env = {"HYPRLAND_INSTANCE_SIGNATURE": signature} if signature else None
    if ctx.run(["hyprctl", "reload"], env=env) == 0:
        ok("hyprland reloaded")
    else:
        info("hyprland did not take the reload; it lands at next login")


def apply_greeter(ctx, repo) -> None:
    src = repo.root / "sddm" / "zenix" / "theme.conf"
    if not src.is_file():
        return
    if SDDM_THEME_DIR.is_dir() or ctx.dry_run:
        ctx.run(["sudo", "install", "-m", "644", str(src),
                 str(SDDM_THEME_DIR / "theme.conf")])
        ok("greeter palette installed")
    else:
        info(f"{SDDM_THEME_DIR} not present; run install.sh to deploy the theme")


def report_deferred(ctx, repo) -> None:
    """What cannot be applied to a running process, said plainly."""
    if capture(["pgrep", "-x", "btop"]):
        warn("btop is running and rewrites btop.conf on exit; quit it first")
    info("ghostty applies `theme =` to new windows only")
    info("nvim, lazygit, fzf and btop pick the palette up on next launch")
    info("the greeter and the GTK3 session apply at next login")
    if (repo.root / "grub" / "theme" / "theme.txt").is_file():
        info("grub needs ./install.sh to copy the theme to /boot")


# -- set ---------------------------------------------------------------------


def cmd_set(ctx, repo, args) -> None:
    header(f"Setting the theme to {args.name}")

    t = gen.load(repo, args.name)
    files = gen.plan(t, repo)

    written = 0
    for path, text in sorted(files.items()):
        if path.is_file() and path.read_text() == text:
            continue
        ctx.write(path, text)
        written += 1
    ok(f"{written} file(s) written, {len(files) - written} already current")

    repo.set_shell_var(ctx, THEME_VAR, t.name)
    ok(f"install.sh: {THEME_VAR}={t.name}")

    if not ctx.apply:
        info("repo updated; the running system was left alone")
        return

    # Most configs are symlinks back into the repo, so writing the repo above
    # already wrote the live config. What is left is telling the daemons.
    apply_qt6ct(ctx, repo)
    apply_tmux(ctx, repo)
    apply_waybar(ctx)
    apply_hyprland(ctx)
    apply_gsettings(ctx, t)
    apply_papirus(ctx, t)
    apply_greeter(ctx, repo)
    report_deferred(ctx, repo)
