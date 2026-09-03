"""commands/status.py — repo against live, on one screen."""

from __future__ import annotations

import unittest
from argparse import Namespace
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import status


class Status(RepoCase):
    def setUp(self):
        super().setUp()
        for patcher in (mock.patch.object(console, "_TTY", False),
                        mock.patch.object(status, "live_zone", return_value="UTC")):
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_status(self):
        return capture(status.cmd_status, self.no_apply, self.repo, Namespace())[1].out

    def test_names_the_repo_it_is_reading(self):
        self.assertIn(str(self.root), self.run_status())

    def test_shows_every_section(self):
        out = self.run_status()
        for section in ("wallpaper", "keyboard", "timezone"):
            self.assertIn(section, out)

    def test_wallpapers_are_shown_with_their_variables(self):
        out = self.run_status()
        self.assertIn("desk.png", out)
        self.assertIn("greet.jpg", out)

    def test_a_wallpaper_missing_from_assets_is_flagged(self):
        (self.repo.wallpaper_dir / "desk.png").unlink()
        out = self.run_status()
        self.assertIn("MISSING", out)

    def test_present_wallpapers_are_not_flagged(self):
        self.assertNotIn("MISSING", self.run_status())

    def test_an_unset_variable_does_not_crash(self):
        self.repo.install_sh.write_text("#!/usr/bin/env bash\n")
        self.assertIn("MISSING", self.run_status())

    def test_reports_whether_the_greeter_background_is_deployed(self):
        with mock.patch.object(status, "SDDM_THEME_DIR", self.tmp / "no-theme"):
            self.assertIn("not deployed", self.run_status())

        theme = self.tmp / "theme"
        theme.mkdir()
        (theme / "background.png").write_bytes(b"x")
        with mock.patch.object(status, "SDDM_THEME_DIR", theme):
            self.assertIn("installed", self.run_status())

    def test_shows_the_keyboard_from_both_sources(self):
        out = self.run_status()
        self.assertIn("hyprland     us", out)
        self.assertIn("archinstall  us", out)
        self.assertIn("variant: -", out)

    def test_shows_a_configured_variant(self):
        self.repo.set_lua_field(self.no_apply, "kb_variant", "dvorak", after="kb_layout")
        self.assertIn("variant: dvorak", self.run_status())

    def test_shows_the_timezone_repo_against_live(self):
        out = self.run_status()
        self.assertIn("Europe/Zagreb", out)
        self.assertIn("UTC", out)

    def test_an_unavailable_timedatectl_reads_as_unknown(self):
        with mock.patch.object(status, "live_zone", return_value=None):
            self.assertIn("unknown", self.run_status())


if __name__ == "__main__":
    unittest.main()
