"""cli.py — parsing, dispatch, and the exit codes."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest import mock

from tests.support import RepoCase, capture

from zenix import __version__, console
from zenix.cli import build_parser, main
from zenix.commands import MODULES, status
from zenix.console import ZenixError


class Parser(unittest.TestCase):
    def setUp(self):
        self.parser = build_parser()

    def parse(self, argv):
        return self.parser.parse_args(argv)

    def test_every_command_module_is_wired_in(self):
        text = self.parser.format_help()
        for name in ("status", "wallpaper", "keyboard", "timezone", "webapp", "agenda"):
            self.assertIn(name, text)
        self.assertEqual(len(MODULES), 6)

    def test_a_command_is_required(self):
        with self.assertRaises(SystemExit):
            capture(self.parse, [])

    def test_an_unknown_command_is_rejected(self):
        with self.assertRaises(SystemExit):
            capture(self.parse, ["nonsense"])

    def test_a_command_needing_an_action_is_rejected_without_one(self):
        for command in ("wallpaper", "keyboard", "timezone", "webapp", "agenda"):
            with self.subTest(command=command):
                with self.assertRaises(SystemExit):
                    capture(self.parse, [command])

    def test_status_needs_no_action(self):
        self.assertEqual(self.parse(["status"]).command, "status")

    def test_global_flags_come_before_the_command(self):
        args = self.parse(["-n", "--repo", "/x", "--no-apply", "status"])
        self.assertTrue(args.dry_run)
        self.assertTrue(args.no_apply)
        self.assertEqual(args.repo, "/x")

    def test_every_subcommand_binds_a_handler(self):
        for argv in (["status"], ["wallpaper", "list"], ["wallpaper", "current"],
                     ["wallpaper", "set", "x.png"], ["keyboard", "list"],
                     ["keyboard", "current"], ["keyboard", "set", "us"],
                     ["timezone", "list"], ["timezone", "current"],
                     ["timezone", "set", "UTC"], ["webapp", "list"],
                     ["webapp", "add", "x", "https://a.b"], ["webapp", "remove", "x"],
                     ["agenda", "fetch"], ["agenda", "show"], ["agenda", "path"]):
            with self.subTest(argv=argv):
                self.assertTrue(callable(self.parse(argv).fn))

    def test_optional_filters_default_to_none(self):
        self.assertIsNone(self.parse(["keyboard", "list"]).filter)
        self.assertIsNone(self.parse(["timezone", "list"]).filter)
        self.assertEqual(self.parse(["timezone", "list", "Europe"]).filter, "Europe")

    def test_wallpaper_set_takes_the_greeter_flag(self):
        self.assertFalse(self.parse(["wallpaper", "set", "x.png"]).greeter)
        self.assertTrue(self.parse(["wallpaper", "set", "x.png", "--greeter"]).greeter)

    def test_keyboard_variant_is_absent_unless_given(self):
        self.assertIsNone(self.parse(["keyboard", "set", "us"]).variant)
        self.assertEqual(self.parse(["keyboard", "set", "us", "--variant", ""]).variant, "")

    def test_webapp_add_defaults(self):
        args = self.parse(["webapp", "add", "whatsapp", "https://a.b"])
        self.assertEqual(args.browser, "brave")
        self.assertEqual(args.categories, "Network;")
        self.assertIsNone(args.title)
        self.assertIsNone(args.icon)


class Main(RepoCase):
    def setUp(self):
        super().setUp()
        # A neutral cwd and home: otherwise the upward search finds whatever
        # checkout the tests happen to be running from.
        self.elsewhere = self.tmp / "elsewhere"
        self.elsewhere.mkdir()
        for patcher in (mock.patch.object(console, "_TTY", False),
                        mock.patch.object(Path, "home", return_value=self.home),
                        mock.patch.object(Path, "cwd", return_value=self.elsewhere)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_main(self, argv):
        return capture(main, argv)

    def test_version_exits_zero_printing_the_version(self):
        with self.assertRaises(SystemExit) as caught:
            _, cap = self.run_main(["--version"])
        self.assertEqual(caught.exception.code, 0)

    def test_a_successful_command_returns_zero(self):
        with mock.patch("zenix.commands.status.live_zone", return_value="UTC"):
            code, cap = self.run_main(["--repo", str(self.root), "status"])
        self.assertEqual(code, 0)
        self.assertIn("desk.png", cap.out)

    def test_a_command_actually_reaches_the_repo(self):
        code, _ = self.run_main(["--repo", str(self.root), "--no-apply",
                                 "timezone", "set", "UTC"])
        self.assertEqual(code, 0)
        self.assertEqual(self.json()["timezone"], "UTC")

    def test_dry_run_reaches_the_command_but_writes_nothing(self):
        code, cap = self.run_main(["--repo", str(self.root), "-n",
                                   "timezone", "set", "UTC"])
        self.assertEqual(code, 0)
        self.assertEqual(self.json()["timezone"], "Europe/Zagreb")
        self.assertIn("$ write", cap.out)

    def test_the_flags_reach_the_context(self):
        seen = {}

        def spy(ctx, repo, args):
            seen["dry_run"] = ctx.dry_run
            seen["apply"] = ctx.apply
            seen["root"] = repo.root

        with mock.patch.object(status, "cmd_status", spy):
            self.run_main(["--repo", str(self.root), "--no-apply", "status"])
        self.assertEqual(seen, {"dry_run": False, "apply": False, "root": self.root})

    def test_a_user_error_prints_without_a_traceback_and_returns_one(self):
        code, cap = self.run_main(["--repo", str(self.tmp / "not-a-repo"), "status"])
        self.assertEqual(code, 1)
        self.assertIn("error:", cap.err)
        self.assertIn("not a zenix checkout", cap.err)
        self.assertEqual(cap.out, "")

    def test_a_bad_repo_flag_is_an_error_even_inside_a_checkout(self):
        """--repo is an assertion: a typo must not quietly edit another repo."""
        with mock.patch.object(Path, "cwd", return_value=self.root):
            code, cap = self.run_main(["--repo", str(self.tmp / "typo"), "status"])
        self.assertEqual(code, 1)
        self.assertIn("not a zenix checkout", cap.err)
        self.assertNotIn(str(self.root), cap.out)

    def test_an_error_raised_inside_a_command_is_caught_too(self):
        def boom(ctx, repo, args):
            raise ZenixError("something the user can fix")

        with mock.patch.object(status, "cmd_status", boom):
            code, cap = self.run_main(["--repo", str(self.root), "status"])
        self.assertEqual(code, 1)
        self.assertIn("something the user can fix", cap.err)

    def test_ctrl_c_returns_130(self):
        def interrupt(ctx, repo, args):
            raise KeyboardInterrupt

        with mock.patch.object(status, "cmd_status", interrupt):
            code, cap = self.run_main(["--repo", str(self.root), "status"])
        self.assertEqual(code, 130)

    def test_an_unexpected_error_is_not_swallowed(self):
        def boom(ctx, repo, args):
            raise RuntimeError("a bug, not a user error")

        with mock.patch.object(status, "cmd_status", boom):
            with self.assertRaises(RuntimeError):
                self.run_main(["--repo", str(self.root), "status"])

    def test_the_env_var_is_honoured_without_repo(self):
        with mock.patch.dict("os.environ", {"ZENIX_REPO": str(self.root)}):
            with mock.patch("zenix.commands.status.live_zone", return_value="UTC"):
                code, cap = self.run_main(["status"])
        self.assertEqual(code, 0)
        self.assertIn(str(self.root), cap.out)


class Module(unittest.TestCase):
    def test_python_m_zenix_is_wired_to_main(self):
        import importlib
        module = importlib.import_module("zenix.__main__")
        self.assertIs(module.main, main)

    def test_the_version_is_a_string(self):
        self.assertRegex(__version__, r"^\d+\.\d+\.\d+$")


if __name__ == "__main__":
    unittest.main()
