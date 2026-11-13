from __future__ import annotations

import json

from zenix import theme as gen
from zenix.config import Config, local_path, parse_value
from zenix.console import die, header, info, ok, paint
from zenix.context import which


def add_parser(sub) -> None:
    p = sub.add_parser("config", help="zenix.json, plus this machine's overrides")
    actions = p.add_subparsers(dest="action", required=True)

    show = actions.add_parser("show", help="print the merged config")
    show.add_argument("--source", action="store_true",
                      help="tag each value with where it came from")
    show.set_defaults(fn=cmd_show)

    get = actions.add_parser("get", help="print one value (dotted key)")
    get.add_argument("key")
    get.set_defaults(fn=cmd_get)

    s = actions.add_parser("set", help="set one value (dotted key, JSON or plain string)")
    s.add_argument("key")
    s.add_argument("value")
    s.add_argument("--local", action="store_true",
                   help="write ~/.config/zenix/config.json instead of the repo")
    s.set_defaults(fn=cmd_set)

    actions.add_parser("path", help="where the two files live").set_defaults(fn=cmd_path)


def _leaves(data: dict, prefix: str = ""):
    for key, value in data.items():
        dotted = f"{prefix}{key}"
        if isinstance(value, dict) and value:
            yield from _leaves(value, dotted + ".")
        else:
            yield dotted, value


def cmd_show(ctx, repo, args) -> None:
    cfg = Config.load(repo)
    if not args.source:
        print(json.dumps(cfg.data, indent=2, ensure_ascii=False))
        return
    header("zenix config")
    rows = list(_leaves(cfg.data))
    width = max((len(k) for k, _ in rows), default=0)
    for key, value in rows:
        tag = paint("33", "local") if cfg.source(key) == "local" else paint("2", "repo")
        print(f"    {key:<{width}}  {json.dumps(value, ensure_ascii=False)}  {tag}")


def cmd_get(ctx, repo, args) -> None:
    value = Config.load(repo).get(args.key)
    if value is None:
        die(f"{args.key} is not set")
    print(value if isinstance(value, str) else json.dumps(value, ensure_ascii=False))


def cmd_set(ctx, repo, args) -> None:
    value = parse_value(args.value)
    target = Config.load(repo).set(ctx, args.key, value, local=args.local)
    ok(f"{target}: {args.key} = {json.dumps(value, ensure_ascii=False)}")
    if args.key == "waybar" or args.key.startswith("waybar."):
        apply_bar(ctx, repo)


def apply_bar(ctx, repo) -> None:
    name = Config.load(repo).get("theme")
    if name not in gen.names(repo):
        return
    for path, text in gen.bar_files(gen.load(repo, name), repo).items():
        if path.read_text() != text:
            ctx.write(path, text)
            ok(f"{path.relative_to(repo.root)} updated")
    if ctx.apply and which("pkill") and ctx.run(["pkill", "-SIGUSR2", "waybar"]) == 0:
        ok("waybar reloaded")


def cmd_path(ctx, repo, args) -> None:
    info(f"repo:  {repo.zenix_json}")
    local = local_path()
    info(f"local: {local}" + ("" if local.is_file() else paint("2", "  (absent)")))
