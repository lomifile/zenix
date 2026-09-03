"""context.py — the mode flags and the two side effects."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from tests.support import capture

from zenix import console
from zenix.context import Context, capture as capture_cmd, which


class Modes(unittest.TestCase):
    def test_default_applies(self):
        ctx = Context()
        self.assertFalse(ctx.dry_run)
        self.assertTrue(ctx.apply)

    def test_no_apply_writes_the_repo_only(self):
        ctx = Context(no_apply=True)
        self.assertFalse(ctx.dry_run)
        self.assertFalse(ctx.apply)

    def test_dry_run_implies_no_apply(self):
        ctx = Context(dry_run=True)
        self.assertTrue(ctx.dry_run)
        self.assertFalse(ctx.apply)

    def test_both_flags_together_stay_dry(self):
        ctx = Context(dry_run=True, no_apply=True)
        self.assertTrue(ctx.dry_run)
        self.assertFalse(ctx.apply)


class Run(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_dry_run_prints_the_command_and_runs_nothing(self):
        with mock.patch("zenix.context.subprocess.run") as runner:
            code, cap = capture(Context(dry_run=True).run, ["hyprctl", "reload"])
        runner.assert_not_called()
        self.assertEqual(code, 0)
        self.assertIn("$ hyprctl reload", cap.out)

    def test_success_returns_zero_and_says_nothing(self):
        done = subprocess.CompletedProcess(["true"], 0, "", "")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            code, cap = capture(Context().run, ["true"])
        self.assertEqual(code, 0)
        self.assertEqual(cap.all, "")

    def test_missing_binary_warns_and_returns_127(self):
        with mock.patch("zenix.context.subprocess.run", side_effect=FileNotFoundError):
            code, cap = capture(Context().run, ["nope", "--x"])
        self.assertEqual(code, 127)
        self.assertIn("nope not found", cap.err)

    def test_failure_warns_with_the_first_line_of_stderr(self):
        done = subprocess.CompletedProcess(["hyprctl"], 1, "stdout line", "boom\nrest")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            code, cap = capture(Context().run, ["hyprctl", "reload"])
        self.assertEqual(code, 1)
        self.assertIn("hyprctl reload failed: boom", cap.err)
        self.assertNotIn("rest", cap.err)

    def test_failure_falls_back_to_stdout(self):
        done = subprocess.CompletedProcess(["x"], 2, "only stdout", "")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            _, cap = capture(Context().run, ["x"])
        self.assertIn("only stdout", cap.err)

    def test_failure_with_no_output_reports_the_code(self):
        done = subprocess.CompletedProcess(["x"], 3, "", "")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            _, cap = capture(Context().run, ["x"])
        self.assertIn("failed: 3", cap.err)


class Write(unittest.TestCase):
    def setUp(self):
        self._tmp = TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_creates_missing_parents(self):
        target = self.tmp / "a" / "b" / "conf"
        Context().write(target, "body\n")
        self.assertEqual(target.read_text(), "body\n")

    def test_overwrites(self):
        target = self.tmp / "conf"
        target.write_text("old")
        Context().write(target, "new")
        self.assertEqual(target.read_text(), "new")

    def test_dry_run_prints_and_writes_nothing(self):
        target = self.tmp / "conf"
        _, cap = capture(Context(dry_run=True).write, target, "body")
        self.assertFalse(target.exists())
        self.assertIn(f"$ write {target}", cap.out)

    def test_no_apply_still_writes_the_repo(self):
        target = self.tmp / "conf"
        Context(no_apply=True).write(target, "body")
        self.assertEqual(target.read_text(), "body")


class Which(unittest.TestCase):
    def test_true_for_a_binary_on_path(self):
        with mock.patch("zenix.context.shutil.which", return_value="/usr/bin/sh"):
            self.assertTrue(which("sh"))

    def test_false_when_absent(self):
        with mock.patch("zenix.context.shutil.which", return_value=None):
            self.assertFalse(which("definitely-not-installed"))


class CaptureCmd(unittest.TestCase):
    def test_returns_stripped_stdout(self):
        done = subprocess.CompletedProcess(["x"], 0, "  Europe/Zagreb \n", "")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            self.assertEqual(capture_cmd(["x"]), "Europe/Zagreb")

    def test_none_on_non_zero_exit(self):
        done = subprocess.CompletedProcess(["x"], 1, "output", "")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            self.assertIsNone(capture_cmd(["x"]))

    def test_none_when_the_binary_is_missing(self):
        with mock.patch("zenix.context.subprocess.run", side_effect=FileNotFoundError):
            self.assertIsNone(capture_cmd(["nope"]))

    def test_none_when_not_executable(self):
        with mock.patch("zenix.context.subprocess.run", side_effect=PermissionError):
            self.assertIsNone(capture_cmd(["nope"]))

    def test_does_not_print(self):
        done = subprocess.CompletedProcess(["x"], 0, "quiet", "")
        with mock.patch("zenix.context.subprocess.run", return_value=done):
            _, cap = capture(capture_cmd, ["x"])
        self.assertEqual(cap.all, "")


if __name__ == "__main__":
    unittest.main()
