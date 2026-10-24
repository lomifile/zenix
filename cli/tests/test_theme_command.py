"""commands/theme.py — switching the colour theme."""

from __future__ import annotations

import json
import unittest
from argparse import Namespace
from pathlib import Path
from unittest import mock

from tests.support import RepoCase, capture, make_theme

from zenix import console
from zenix.commands import theme
from zenix.console import ZenixError


class ThemeCase(RepoCase):
    def setUp(self):
        super().setUp()
        for patcher in (
            mock.patch.object(console, "_TTY", False),
            mock.patch.object(Path, "home", return_value=self.home),
            # Nothing in these tests may reach the real machine.
            mock.patch.object(theme, "which", return_value=False),
            mock.patch.object(theme, "capture", return_value=None),
            mock.patch.object(theme, "SDDM_THEME_DIR", self.home / "sddm"),
            mock.patch.object(theme, "gtk_theme_installed", return_value=True),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def args(self, **kw):
        return Namespace(**{"name": None, **kw})

    def applying(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        return ctx


class CmdList(ThemeCase):
    def test_tags_the_current_theme(self):
        _, cap = capture(theme.cmd_list, self.no_apply, self.repo, self.args())
        self.assertIn("fixture", cap.out)
        self.assertIn("current", cap.out)

    def test_an_other_theme_is_listed_without_the_tag(self):
        make_theme(self.root, "other")
        _, cap = capture(theme.cmd_list, self.no_apply, self.repo, self.args())
        line = next(ln for ln in cap.out.splitlines() if "other" in ln)
        self.assertNotIn("current", line)

    def test_an_empty_themes_directory_warns(self):
        (self.root / "themes" / "fixture.json").unlink()
        _, cap = capture(theme.cmd_list, self.no_apply, self.repo, self.args())
        self.assertIn("none found", cap.all)


class CmdShow(ThemeCase):
    def test_prints_the_roles(self):
        _, cap = capture(theme.cmd_show, self.no_apply, self.repo, self.args(name="fixture"))
        self.assertIn("accent", cap.out)
        self.assertIn("editor", cap.out)

    def test_prose_keys_are_not_printed_as_colours(self):
        _, cap = capture(theme.cmd_show, self.no_apply, self.repo, self.args(name="fixture"))
        self.assertNotIn("_comment", cap.out)

    def test_the_comment_colour_is_still_shown(self):
        # editor.comment is a role, not prose -- the two must not be confused.
        _, cap = capture(theme.cmd_show, self.no_apply, self.repo, self.args(name="fixture"))
        self.assertIn("comment", cap.out)


class CmdCurrent(ThemeCase):
    def test_names_the_selected_theme(self):
        _, cap = capture(theme.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("fixture", cap.out)
        self.assertIn("Fixture Theme", cap.out)

    def test_in_sync_when_the_generated_files_are_current(self):
        capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="fixture"))
        _, cap = capture(theme.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("in sync", cap.out)

    def test_a_stale_generated_file_is_named(self):
        capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="fixture"))
        palette = self.root / "nvim" / "lua" / "zenix" / "palette.lua"
        palette.write_text("return {}\n")
        _, cap = capture(theme.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("out of date", cap.all)
        self.assertIn("palette.lua", cap.all)

    def test_an_unset_variable_says_so(self):
        self.repo.install_sh.write_text("#!/usr/bin/env bash\n")
        _, cap = capture(theme.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("not set", cap.all)


class CmdSet(ThemeCase):
    def test_writes_the_generated_files(self):
        capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="fixture"))
        self.assertTrue((self.root / "ghostty" / "themes" / "fixture").is_file())
        self.assertTrue((self.root / "btop" / "themes" / "fixture.theme").is_file())
        self.assertTrue((self.root / "nvim" / "lua" / "zenix" / "palette.lua").is_file())
        self.assertTrue((self.root / "shell" / "Commons" / "Theme.qml").is_file())

    def test_records_the_choice_in_install_sh(self):
        make_theme(self.root, "other")
        capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="other"))
        self.assertIn('THEME_NAME="other"', self.install_sh())

    def test_the_neighbouring_variables_survive(self):
        make_theme(self.root, "other")
        capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="other"))
        self.assertIn('WALLPAPER_NAME="desk.png"', self.install_sh())
        self.assertIn('GREETER_WALLPAPER_NAME="greet.jpg"', self.install_sh())

    def test_an_unknown_theme_is_refused_and_changes_nothing(self):
        with self.assertRaises(ZenixError) as caught:
            capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="nope"))
        self.assertIn("fixture", str(caught.exception))
        self.assertIn('THEME_NAME="fixture"', self.install_sh())

    def test_is_idempotent(self):
        capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="fixture"))
        before = (self.root / "ghostty" / "themes" / "fixture").read_text()
        _, cap = capture(theme.cmd_set, self.no_apply, self.repo, self.args(name="fixture"))
        after = (self.root / "ghostty" / "themes" / "fixture").read_text()
        self.assertEqual(before, after)
        self.assertIn("0 file(s) written", cap.out)

    def test_no_apply_stops_before_touching_the_system(self):
        ctx = mock.Mock(dry_run=False, apply=False)
        _, cap = capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        ctx.run.assert_not_called()
        self.assertIn("left alone", cap.out)

    def test_dry_run_writes_nothing_and_says_what_it_would(self):
        _, cap = capture(theme.cmd_set, self.dry, self.repo, self.args(name="fixture"))
        self.assertFalse((self.root / "ghostty" / "themes" / "fixture").exists())
        self.assertFalse((self.home / ".config").exists())
        self.assertIn("$ write", cap.out)

    def test_applying_reloads_the_running_surfaces(self):
        with mock.patch.object(theme, "which", return_value=True), \
             mock.patch.object(theme, "live_hypr_instance", return_value="sig"):
            ctx = self.applying()
            capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertIn(["pkill", "-SIGUSR2", "waybar"], called)
        self.assertIn(["hyprctl", "reload"], called)

    def test_the_hyprland_reload_uses_the_live_signature(self):
        # A tmux server outliving a session hands down a dead signature.
        with mock.patch.object(theme, "which", return_value=True), \
             mock.patch.object(theme, "live_hypr_instance", return_value="fresh"):
            ctx = self.applying()
            capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        reload_call = next(c for c in ctx.run.call_args_list
                           if c.args[0] == ["hyprctl", "reload"])
        self.assertEqual(reload_call.kwargs["env"],
                         {"HYPRLAND_INSTANCE_SIGNATURE": "fresh"})

    def test_gsettings_follows_the_themes_light_or_dark_flag(self):
        make_theme(self.root, "day", background="light")
        with mock.patch.object(theme, "which", return_value=True):
            ctx = self.applying()
            capture(theme.cmd_set, ctx, self.repo, self.args(name="day"))
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertIn(
            ["gsettings", "set", theme.GSETTINGS_IFACE, "color-scheme", "prefer-light"],
            called,
        )

    def test_the_folder_colour_is_restored_rather_than_left_behind(self):
        # papirus-folders is global system state, so every theme names one.
        with mock.patch.object(theme, "which", return_value=True):
            ctx = self.applying()
            capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertIn(
            ["sudo", "papirus-folders", "-C", "blue", "-t", "Papirus-Dark"], called
        )

    def test_a_missing_greeter_directory_points_at_install_sh(self):
        (self.root / "sddm" / "zenix").mkdir(parents=True)
        (self.root / "sddm" / "zenix" / "theme.conf").write_text(
            "[General]\n# >>> zenix theme <<<\nbackgroundColor=#000000\n"
            "# >>> end zenix theme <<<\n"
        )
        ctx = self.applying()
        _, cap = capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        self.assertIn("run install.sh", cap.all)

    def test_the_live_qt_config_gets_the_real_home_not_the_placeholder(self):
        qt = self.root / "qt6ct"
        qt.mkdir()
        (qt / "qt6ct.conf").write_text(
            "[Appearance]\ncolor_scheme_path=/usr/share/qt6ct/colors/darker.conf\n"
        )
        # A real Context, so the repo write actually lands before the apply
        # step reads it back -- which is the ordering being tested.
        capture(theme.cmd_set, self.live, self.repo, self.args(name="fixture"))
        live = (self.home / ".config" / "qt6ct" / "qt6ct.conf").read_text()
        self.assertNotIn("__HOME__", live)
        self.assertIn(f"{self.home}/.config/qt6ct/colors/fixture.conf", live)
        # The repo copy keeps the placeholder, so it stays machine-independent.
        self.assertIn("__HOME__", (qt / "qt6ct.conf").read_text())

    def test_a_running_btop_is_called_out(self):
        # btop rewrites its own config on exit, which would undo the switch.
        with mock.patch.object(theme, "capture", return_value="1234"):
            ctx = self.applying()
            _, cap = capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        self.assertIn("btop is running", cap.all)

    def test_a_failed_greeter_install_is_not_reported_as_success(self):
        (self.root / "sddm" / "zenix").mkdir(parents=True)
        (self.root / "sddm" / "zenix" / "theme.conf").write_text(
            "[General]\n# >>> zenix theme <<<\nbackgroundColor=#000000\n"
            "# >>> end zenix theme <<<\n"
        )
        (self.home / "sddm").mkdir()
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 1          # e.g. sudo could not read a password
        _, cap = capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        self.assertNotIn("greeter palette installed", cap.all)
        self.assertIn("not installed", cap.all)

    def test_a_missing_gtk_theme_is_flagged_before_it_bites(self):
        # GTK_THEME is read at session start, so naming an uninstalled theme
        # shows up only at next login -- too late to be useful.
        with mock.patch.object(theme, "gtk_theme_installed", return_value=False), \
             mock.patch.object(theme, "which", return_value=True):
            ctx = self.applying()
            _, cap = capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        self.assertIn("not installed", cap.all)
        self.assertIn("Fixture-dark", cap.all)

    def test_the_gtk3_caveat_is_stated_rather_than_glossed(self):
        # GTK_THEME is set in the session and overrides gsettings for GTK3.
        with mock.patch.object(theme, "which", return_value=True):
            ctx = self.applying()
            _, cap = capture(theme.cmd_set, ctx, self.repo, self.args(name="fixture"))
        self.assertIn("next login", cap.all)


if __name__ == "__main__":
    unittest.main()
