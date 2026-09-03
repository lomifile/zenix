"""repo.py — finding the checkout and editing the files inside it."""

from __future__ import annotations

import json
import os
import unittest
from pathlib import Path
from unittest import mock

from tests.support import RepoCase, capture, make_repo

from zenix import console
from zenix.console import ZenixError
from zenix.repo import GREETER_SUFFIXES, IMAGE_SUFFIXES, Repo, find_repo


class FindRepo(RepoCase):
    """The order in the README is the order it must actually try."""

    def setUp(self):
        super().setUp()
        # An unrelated cwd and home, so nothing resolves by accident.
        elsewhere = self.tmp / "elsewhere"
        elsewhere.mkdir()
        for patcher in (mock.patch.object(Path, "cwd", return_value=elsewhere),
                        mock.patch.object(Path, "home", return_value=self.home),
                        mock.patch.dict("os.environ", {}, clear=False)):
            patcher.start()
            self.addCleanup(patcher.stop)
        os.environ.pop("ZENIX_REPO", None)
        # expanduser() reads $HOME, not Path.home(), so both have to move.
        os.environ["HOME"] = str(self.home)

    def test_explicit_path_wins(self):
        other = make_repo(self.tmp / "other")
        os.environ["ZENIX_REPO"] = str(other.root)
        self.assertEqual(find_repo(str(self.root)), self.root)

    def test_explicit_path_expands_a_tilde(self):
        make_repo(self.home / "checkout")
        self.assertEqual(find_repo("~/checkout"), self.home / "checkout")

    def test_an_explicit_path_never_falls_through_to_the_search(self):
        # Standing inside a valid checkout must not rescue a bad --repo.
        with mock.patch.object(Path, "cwd", return_value=self.root):
            with self.assertRaises(ZenixError):
                find_repo(str(self.tmp / "typo"))

    def test_an_explicit_path_outranks_the_home_fallback(self):
        make_repo(self.home / "build" / "zenix")
        with self.assertRaises(ZenixError):
            find_repo(str(self.tmp / "typo"))

    def test_explicit_non_checkout_is_an_error_naming_the_markers(self):
        with self.assertRaises(ZenixError) as caught:
            find_repo(str(self.tmp / "elsewhere"))
        message = str(caught.exception)
        self.assertIn("not a zenix checkout", message)
        self.assertIn("install.sh", message)

    def test_env_var_is_used_next(self):
        os.environ["ZENIX_REPO"] = str(self.root)
        self.assertEqual(find_repo(), self.root)

    def test_a_bad_env_var_falls_through_rather_than_failing(self):
        os.environ["ZENIX_REPO"] = str(self.tmp / "gone")
        make_repo(self.home / "build" / "zenix")
        self.assertEqual(find_repo(), self.home / "build" / "zenix")

    def test_searches_upward_from_the_cwd(self):
        deep = self.root / "hypr"
        with mock.patch.object(Path, "cwd", return_value=deep):
            self.assertEqual(find_repo(), self.root)

    def test_the_cwd_itself_counts(self):
        with mock.patch.object(Path, "cwd", return_value=self.root):
            self.assertEqual(find_repo(), self.root)

    def test_falls_back_to_home_build_zenix(self):
        expected = make_repo(self.home / "build" / "zenix").root
        self.assertEqual(find_repo(), expected)

    def test_no_candidate_at_all_is_an_error_listing_the_three_ways(self):
        with self.assertRaises(ZenixError) as caught:
            find_repo()
        message = str(caught.exception)
        self.assertIn("--repo", message)
        self.assertIn("ZENIX_REPO", message)

    def test_a_git_repo_without_the_markers_is_not_a_match(self):
        bare = self.tmp / "bare"
        (bare / ".git").mkdir(parents=True)
        (bare / "install.sh").write_text("")  # only one of the two markers
        with mock.patch.object(Path, "cwd", return_value=bare):
            with self.assertRaises(ZenixError):
                find_repo()


class Paths(RepoCase):
    def test_points_at_the_files_the_cli_edits(self):
        self.assertEqual(self.repo.install_sh, self.root / "install.sh")
        self.assertEqual(self.repo.hyprland_lua, self.root / "hypr" / "hyprland.lua")
        self.assertEqual(self.repo.archinstall, self.root / "user_configuration.json")
        self.assertEqual(self.repo.wallpaper_dir, self.root / "assets" / "wallpaper")


class Wallpapers(RepoCase):
    def test_sorted_and_filtered_to_images(self):
        wall = self.repo.wallpaper_dir
        (wall / "notes.txt").write_text("x")
        (wall / "anim.webp").write_bytes(b"x")
        (wall / "subdir").mkdir()
        names = [p.name for p in self.repo.wallpapers()]
        self.assertEqual(names, ["anim.webp", "desk.png", "greet.jpg"])

    def test_suffix_match_is_case_insensitive(self):
        (self.repo.wallpaper_dir / "SHOUT.PNG").write_bytes(b"x")
        self.assertIn("SHOUT.PNG", [p.name for p in self.repo.wallpapers()])

    def test_missing_directory_is_empty_not_an_error(self):
        empty = Repo(self.tmp / "no-such-repo")
        self.assertEqual(empty.wallpapers(), [])

    def test_webp_is_a_desktop_only_format(self):
        self.assertIn(".webp", IMAGE_SUFFIXES)
        self.assertNotIn(".webp", GREETER_SUFFIXES)
        self.assertTrue(GREETER_SUFFIXES < IMAGE_SUFFIXES)


class ShellVar(RepoCase):
    def test_reads_a_quoted_assignment(self):
        self.assertEqual(self.repo.read_shell_var("WALLPAPER_NAME"), "desk.png")
        self.assertEqual(self.repo.read_shell_var("GREETER_WALLPAPER_NAME"), "greet.jpg")

    def test_unknown_var_is_none(self):
        self.assertIsNone(self.repo.read_shell_var("NOPE"))

    def test_an_indented_assignment_is_not_the_top_level_one(self):
        self.repo.install_sh.write_text('  INDENTED="x"\n')
        self.assertIsNone(self.repo.read_shell_var("INDENTED"))

    def test_set_replaces_only_the_value(self):
        self.repo.set_shell_var(self.no_apply, "WALLPAPER_NAME", "new.png")
        text = self.install_sh()
        self.assertIn('WALLPAPER_NAME="new.png"', text)
        self.assertIn('GREETER_WALLPAPER_NAME="greet.jpg"', text)
        self.assertIn("set -euo pipefail", text)

    def test_set_is_a_no_op_under_dry_run(self):
        with mock.patch.object(console, "_TTY", False):
            capture(self.repo.set_shell_var, self.dry, "WALLPAPER_NAME", "new.png")
        self.assertIn('WALLPAPER_NAME="desk.png"', self.install_sh())

    def test_setting_a_prefix_does_not_hit_the_longer_name(self):
        self.repo.set_shell_var(self.no_apply, "WALLPAPER_NAME", "x.png")
        self.assertIn('GREETER_WALLPAPER_NAME="greet.jpg"', self.install_sh())

    def test_a_missing_var_is_a_sync_error(self):
        with self.assertRaises(ZenixError) as caught:
            self.repo.set_shell_var(self.no_apply, "GONE", "x")
        self.assertIn("out of sync", str(caught.exception))


class LuaField(RepoCase):
    def test_reads_a_field(self):
        self.assertEqual(self.repo.read_lua_field("kb_layout"), "us")

    def test_absent_field_is_none(self):
        self.assertIsNone(self.repo.read_lua_field("kb_variant"))

    def test_set_replaces_in_place(self):
        self.repo.set_lua_field(self.no_apply, "kb_layout", "hr", after="kb_layout")
        self.assertIn('kb_layout = "hr"', self.lua())
        self.assertEqual(self.repo.read_lua_field("kb_layout"), "hr")

    def test_set_inserts_after_the_anchor_keeping_its_indent(self):
        self.repo.set_lua_field(self.no_apply, "kb_variant", "dvorak", after="kb_layout")
        lines = self.lua().splitlines()
        layout = next(i for i, l in enumerate(lines) if "kb_layout" in l)
        self.assertEqual(lines[layout + 1], '\t\tkb_variant = "dvorak",')

    def test_an_inserted_field_reads_back(self):
        self.repo.set_lua_field(self.no_apply, "kb_variant", "dvorak", after="kb_layout")
        self.assertEqual(self.repo.read_lua_field("kb_variant"), "dvorak")

    def test_an_empty_value_clears_the_field(self):
        self.repo.set_lua_field(self.no_apply, "kb_variant", "", after="kb_layout")
        self.assertEqual(self.repo.read_lua_field("kb_variant"), "")

    def test_a_missing_anchor_is_an_error(self):
        self.repo.hyprland_lua.write_text("return {}\n")
        with self.assertRaises(ZenixError) as caught:
            self.repo.set_lua_field(self.no_apply, "kb_variant", "x", after="kb_layout")
        self.assertIn("no kb_layout line", str(caught.exception))

    def test_dry_run_writes_nothing(self):
        with mock.patch.object(console, "_TTY", False):
            capture(self.repo.set_lua_field, self.dry, "kb_layout", "hr", after="kb_layout")
        self.assertEqual(self.repo.read_lua_field("kb_layout"), "us")


class Archinstall(RepoCase):
    def test_load_returns_the_data_and_the_trailing_newline(self):
        data, trailing = self.repo.load_archinstall()
        self.assertEqual(data["timezone"], "Europe/Zagreb")
        self.assertTrue(trailing)

    def test_load_notices_a_file_without_a_trailing_newline(self):
        repo = make_repo(self.tmp / "nonl", trailing_nl=False)
        _, trailing = repo.load_archinstall()
        self.assertFalse(trailing)

    def test_save_keeps_archinstalls_formatting(self):
        data, trailing = self.repo.load_archinstall()
        data["timezone"] = "UTC"
        self.repo.save_archinstall(self.no_apply, data, trailing)
        text = self.repo.archinstall.read_text()
        self.assertTrue(text.endswith("}\n"))
        self.assertIn('    "timezone": "UTC"', text)
        # sort_keys, so locale_config precedes timezone
        self.assertLess(text.index("locale_config"), text.index("timezone"))

    def test_save_without_a_trailing_newline_adds_none(self):
        data, _ = self.repo.load_archinstall()
        self.repo.save_archinstall(self.no_apply, data, False)
        self.assertFalse(self.repo.archinstall.read_text().endswith("\n"))

    def test_round_trip_of_an_untouched_file_changes_nothing(self):
        before = self.repo.archinstall.read_text()
        data, trailing = self.repo.load_archinstall()
        self.repo.save_archinstall(self.no_apply, data, trailing)
        self.assertEqual(self.repo.archinstall.read_text(), before)

    def test_save_is_a_no_op_under_dry_run(self):
        before = self.repo.archinstall.read_text()
        data, trailing = self.repo.load_archinstall()
        data["timezone"] = "UTC"
        with mock.patch.object(console, "_TTY", False):
            capture(self.repo.save_archinstall, self.dry, data, trailing)
        self.assertEqual(self.repo.archinstall.read_text(), before)

    def test_invalid_json_raises(self):
        self.repo.archinstall.write_text("{ nope")
        with self.assertRaises(json.JSONDecodeError):
            self.repo.load_archinstall()


if __name__ == "__main__":
    unittest.main()
