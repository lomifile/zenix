"""Argument parsing and dispatch."""

from __future__ import annotations

import argparse
import sys

from zenix import __version__
from zenix.commands import MODULES
from zenix.console import ZenixError, paint
from zenix.context import Context
from zenix.repo import Repo, find_repo


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="zenix",
        description="Manage the parts of the zenix setup that change often.",
        epilog="Every command writes the repo first, then the running system.",
    )
    parser.add_argument("--version", action="version", version=f"zenix {__version__}")
    parser.add_argument("--repo", metavar="PATH",
                        help="path to the zenix checkout (default: search upward, then $ZENIX_REPO)")
    parser.add_argument("-n", "--dry-run", action="store_true",
                        help="print what would change, touch nothing")
    parser.add_argument("--no-apply", action="store_true",
                        help="write the repo but leave the running system alone")

    sub = parser.add_subparsers(dest="command", required=True)
    for module in MODULES:
        module.add_parser(sub)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        repo = Repo(find_repo(args.repo))
        ctx = Context(dry_run=args.dry_run, no_apply=args.no_apply)
        args.fn(ctx, repo, args)
    except ZenixError as exc:
        print(f"\n{paint('31', 'error:')} {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print()
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
