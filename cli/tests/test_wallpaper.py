"""commands/wallpaper.py — desktop and greeter wallpapers."""

from __future__ import annotations

import unittest
from argparse import Namespace
from pathlib import Path
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import wallpaper
from zenix.console import ZenixError


class WallpaperCase(RepoCase):
    def setUp(self):
        super().setUp()
        for patcher in (mock.patch.object(console, "_TTY", False),
                        mock.patch.object(Path, "home", return_value=self.home)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def args(self, name, greeter=False):
        return Namespace(name=name, greeter=greeter)


class Resolve(WallpaperCase):
    def test_a_name_inside_the_assets_dir(self):
        self.assertEqual(wallpaper.resolve(self.repo, "desk.png", greeter=False),
                         self.repo.wallpaper_dir / "desk.png")

    def test_a_path_from_outside(self):
        outside = self.tmp / "elsewhere.png"
        outside.write_bytes(b"x")
        self.assertEqual(wallpaper.resolve(self.repo, str(outside), greeter=False), outside)

    def test_a_path_with_a_tilde(self):
        (self.home / "Downloads").mkdir()
        outside = self.home / "Downloads" / "grab.png"
        outside.write_bytes(b"x")
        with mock.patch.dict("os.environ", {"HOME": str(self.home)}):
            self.assertEqual(
                wallpaper.resolve(self.repo, "~/Downloads/grab.png", greeter=False),
                outside)

    def test_an_unknown_name_points_at_the_list_command(self):
        with self.assertRaises(ZenixError) as caught:
            wallpaper.resolve(self.repo, "nope.png", greeter=False)
        self.assertIn("zenix wallpaper list", str(caught.exception))

    def test_a_non_image_is_rejected(self):
        bad = self.repo.wallpaper_dir / "notes.txt"
        bad.write_text("x")
        with self.assertRaises(ZenixError) as caught:
            wallpaper.resolve(self.repo, "notes.txt", greeter=False)
        self.assertIn("not an image", str(caught.exception))

    def test_webp_is_fine_for_the_desktop(self):
        (self.repo.wallpaper_dir / "anim.webp").write_bytes(b"x")
        self.assertEqual(wallpaper.resolve(self.repo, "anim.webp", greeter=False).name,
                         "anim.webp")

    def test_webp_is_refused_for_the_greeter_with_the_reason(self):
        (self.repo.wallpaper_dir / "anim.webp").write_bytes(b"x")
        with self.assertRaises(ZenixError) as caught:
            wallpaper.resolve(self.repo, "anim.webp", greeter=True)
        self.assertIn("qt6-imageformats", str(caught.exception))

    def test_suffix_matching_is_case_insensitive(self):
        (self.repo.wallpaper_dir / "SHOUT.JPG").write_bytes(b"x")
        self.assertEqual(wallpaper.resolve(self.repo, "SHOUT.JPG", greeter=True).name,
                         "SHOUT.JPG")


class ImportIntoRepo(WallpaperCase):
    def test_a_file_already_inside_is_left_alone(self):
        src = self.repo.wallpaper_dir / "desk.png"
        name, cap = capture(wallpaper.import_into_repo, self.no_apply, self.repo, src)
        self.assertEqual(name, "desk.png")
        self.assertEqual(cap.all, "")

    def test_an_outside_file_is_copied_in(self):
        src = self.tmp / "new.png"
        src.write_bytes(b"payload")
        name, cap = capture(wallpaper.import_into_repo, self.no_apply, self.repo, src)
        self.assertEqual(name, "new.png")
        self.assertEqual((self.repo.wallpaper_dir / "new.png").read_bytes(), b"payload")
        self.assertIn("imported new.png", cap.out)

    def test_a_name_collision_is_refused_rather_than_overwritten(self):
        src = self.tmp / "desk.png"
        src.write_bytes(b"different")
        with self.assertRaises(ZenixError) as caught:
            wallpaper.import_into_repo(self.no_apply, self.repo, src)
        self.assertIn("already exists", str(caught.exception))
        self.assertNotEqual((self.repo.wallpaper_dir / "desk.png").read_bytes(), b"different")

    def test_dry_run_prints_the_copy_and_makes_none(self):
        src = self.tmp / "new.png"
        src.write_bytes(b"payload")
        name, cap = capture(wallpaper.import_into_repo, self.dry, self.repo, src)
        self.assertEqual(name, "new.png")
        self.assertFalse((self.repo.wallpaper_dir / "new.png").exists())
        self.assertIn("$ cp", cap.out)

    def test_a_missing_assets_dir_is_created(self):
        repo = self.repo
        for p in repo.wallpaper_dir.iterdir():
            p.unlink()
        repo.wallpaper_dir.rmdir()
        src = self.tmp / "new.png"
        src.write_bytes(b"payload")
        capture(wallpaper.import_into_repo, self.no_apply, repo, src)
        self.assertTrue((repo.wallpaper_dir / "new.png").is_file())


class ApplyDesktop(WallpaperCase):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(wallpaper, "which", return_value=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def conf(self) -> Path:
        return self.home / ".config" / "hypr" / "hyprpaper.conf"

    def test_copies_the_image_into_pictures_and_writes_the_conf(self):
        _, cap = capture(wallpaper.apply_desktop, self.no_apply, self.repo, "desk.png")
        live = self.home / "Pictures" / "wallpaper" / "desk.png"
        self.assertTrue(live.is_file())
        text = self.conf().read_text()
        self.assertIn(f"path = {live}", text)
        self.assertIn("fit_mode = cover", text)
        self.assertIn("ipc = on", text)
        self.assertIn("next login", cap.all)

    def test_an_existing_live_copy_is_not_overwritten(self):
        live = self.home / "Pictures" / "wallpaper" / "desk.png"
        live.parent.mkdir(parents=True)
        live.write_bytes(b"already here")
        capture(wallpaper.apply_desktop, self.no_apply, self.repo, "desk.png")
        self.assertEqual(live.read_bytes(), b"already here")

    def test_dry_run_copies_nothing_and_writes_nothing(self):
        _, cap = capture(wallpaper.apply_desktop, self.dry, self.repo, "desk.png")
        self.assertFalse((self.home / "Pictures").exists())
        self.assertFalse(self.conf().exists())
        self.assertIn("$ write", cap.out)

    def running(self, signature="sig_1"):
        return mock.patch.object(wallpaper, "live_hypr_instance", return_value=signature)

    def test_hyprctl_is_asked_to_load_the_image_when_present(self):
        with mock.patch.object(wallpaper, "which", return_value=True), self.running():
            ctx = mock.Mock(dry_run=False, apply=True)
            ctx.run.return_value = 0
            capture(wallpaper.apply_desktop, ctx, self.repo, "desk.png")
        live = self.home / "Pictures" / "wallpaper" / "desk.png"
        ctx.run.assert_called_once_with(
            ["hyprctl", "hyprpaper", "wallpaper", f",{live}"],
            env={"HYPRLAND_INSTANCE_SIGNATURE": "sig_1"},
        )

    def test_the_live_signature_overrides_a_stale_inherited_one(self):
        with mock.patch.object(wallpaper, "which", return_value=True), self.running("fresh"):
            ctx = mock.Mock(dry_run=False, apply=True)
            ctx.run.return_value = 0
            capture(wallpaper.apply_desktop, ctx, self.repo, "desk.png")
        self.assertEqual(
            ctx.run.call_args.kwargs["env"], {"HYPRLAND_INSTANCE_SIGNATURE": "fresh"}
        )

    def test_no_live_compositor_skips_hyprctl_and_says_next_login(self):
        with mock.patch.object(wallpaper, "which", return_value=True), self.running(None):
            ctx = mock.Mock(dry_run=False, apply=True)
            _, cap = capture(wallpaper.apply_desktop, ctx, self.repo, "desk.png")
        ctx.run.assert_not_called()
        self.assertIn("not running", cap.all)

    def test_a_failing_hyprctl_is_reported_as_landing_next_login(self):
        with mock.patch.object(wallpaper, "which", return_value=True), self.running():
            ctx = mock.Mock(dry_run=False, apply=True)
            ctx.run.return_value = 1
            _, cap = capture(wallpaper.apply_desktop, ctx, self.repo, "desk.png")
        self.assertIn("next login", cap.all)


class UpdateHyprlock(WallpaperCase):
    def conf(self) -> Path:
        return self.home / ".config" / "hypr" / "hyprlock.conf"

    def write_conf(self, body: str) -> None:
        self.conf().parent.mkdir(parents=True, exist_ok=True)
        self.conf().write_text(body)

    def test_missing_conf_says_install_sh_will_make_it(self):
        _, cap = capture(wallpaper.update_hyprlock, self.no_apply, "greet.jpg")
        self.assertIn("install.sh will generate it", cap.all)

    def test_rewrites_the_first_path_line_keeping_indent(self):
        self.write_conf("background {\n    monitor =\n    path = /old.png\n}\n")
        capture(wallpaper.update_hyprlock, self.no_apply, "greet.jpg")
        target = self.home / "Pictures" / "wallpaper" / "greet.jpg"
        self.assertIn(f"    path = {target}", self.conf().read_text())

    def test_only_the_first_path_line_is_touched(self):
        self.write_conf("background {\n    path = /old.png\n}\n"
                        "image {\n    path = /avatar.png\n}\n")
        capture(wallpaper.update_hyprlock, self.no_apply, "greet.jpg")
        self.assertIn("path = /avatar.png", self.conf().read_text())

    def test_no_path_line_warns_and_leaves_the_file_alone(self):
        self.write_conf("background {\n    monitor =\n}\n")
        before = self.conf().read_text()
        _, cap = capture(wallpaper.update_hyprlock, self.no_apply, "greet.jpg")
        self.assertIn("no path= line", cap.err)
        self.assertEqual(self.conf().read_text(), before)


class ApplyGreeter(WallpaperCase):
    def test_installs_the_background_as_png_and_follows_with_hyprlock(self):
        src = self.repo.wallpaper_dir / "greet.jpg"
        ctx = mock.Mock(dry_run=True, apply=True)
        ctx.run.return_value = 0
        _, cap = capture(wallpaper.apply_greeter, ctx, src)
        cmd = ctx.run.call_args.args[0]
        self.assertEqual(cmd[:4], ["sudo", "install", "-m", "644"])
        self.assertTrue(cmd[-1].endswith("/themes/zenix/background.png"))
        self.assertIn("greeter background installed", cap.out)

    def test_an_undeployed_theme_dir_points_at_install_sh(self):
        src = self.repo.wallpaper_dir / "greet.jpg"
        ctx = mock.Mock(dry_run=False, apply=True)
        with mock.patch.object(wallpaper, "SDDM_THEME_DIR", self.tmp / "no-theme"):
            _, cap = capture(wallpaper.apply_greeter, ctx, src)
        ctx.run.assert_not_called()
        self.assertIn("run install.sh", cap.all)


class CmdList(WallpaperCase):
    def test_tags_the_current_desktop_and_greeter_choices(self):
        _, cap = capture(wallpaper.cmd_list, self.no_apply, self.repo, self.args(None))
        self.assertIn("desk.png", cap.out)
        self.assertRegex(cap.out, r"desk\.png\s+\S+ MB\s+desktop")
        self.assertRegex(cap.out, r"greet\.jpg\s+\S+ MB\s+greeter")

    def test_flags_webp_as_desktop_only(self):
        (self.repo.wallpaper_dir / "anim.webp").write_bytes(b"x")
        _, cap = capture(wallpaper.cmd_list, self.no_apply, self.repo, self.args(None))
        self.assertIn("webp: desktop only", cap.out)

    def test_an_empty_assets_dir_warns(self):
        for p in self.repo.wallpaper_dir.iterdir():
            p.unlink()
        _, cap = capture(wallpaper.cmd_list, self.no_apply, self.repo, self.args(None))
        self.assertIn("none found", cap.err)


class CmdCurrent(WallpaperCase):
    def test_prints_both_variables(self):
        _, cap = capture(wallpaper.cmd_current, self.no_apply, self.repo, self.args(None))
        self.assertIn("desktop: desk.png", cap.out)
        self.assertIn("greeter: greet.jpg", cap.out)


class CmdSet(WallpaperCase):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(wallpaper, "which", return_value=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_writes_the_repo_variable_first(self):
        (self.repo.wallpaper_dir / "other.png").write_bytes(b"x")
        capture(wallpaper.cmd_set, self.no_apply, self.repo, self.args("other.png"))
        self.assertIn('WALLPAPER_NAME="other.png"', self.install_sh())

    def test_greeter_writes_the_greeter_variable(self):
        (self.repo.wallpaper_dir / "other.jpg").write_bytes(b"x")
        capture(wallpaper.cmd_set, self.no_apply, self.repo,
                self.args("other.jpg", greeter=True))
        text = self.install_sh()
        self.assertIn('GREETER_WALLPAPER_NAME="other.jpg"', text)
        self.assertIn('WALLPAPER_NAME="desk.png"', text)

    def test_no_apply_stops_before_touching_the_system(self):
        _, cap = capture(wallpaper.cmd_set, self.no_apply, self.repo, self.args("desk.png"))
        self.assertIn("left alone", cap.out)
        self.assertFalse((self.home / ".config").exists())

    def test_an_outside_path_is_imported_and_recorded_by_name(self):
        src = self.tmp / "new.png"
        src.write_bytes(b"payload")
        capture(wallpaper.cmd_set, self.no_apply, self.repo, self.args(str(src)))
        self.assertIn('WALLPAPER_NAME="new.png"', self.install_sh())
        self.assertTrue((self.repo.wallpaper_dir / "new.png").is_file())

    def test_applying_reaches_the_desktop(self):
        capture(wallpaper.cmd_set, self.live, self.repo, self.args("desk.png"))
        self.assertTrue((self.home / ".config" / "hypr" / "hyprpaper.conf").is_file())

    def test_an_unknown_name_changes_nothing(self):
        before = self.install_sh()
        with self.assertRaises(ZenixError):
            capture(wallpaper.cmd_set, self.no_apply, self.repo, self.args("nope.png"))
        self.assertEqual(self.install_sh(), before)

    def test_dry_run_touches_neither_repo_nor_system(self):
        _, cap = capture(wallpaper.cmd_set, self.dry, self.repo, self.args("greet.jpg"))
        self.assertIn('WALLPAPER_NAME="desk.png"', self.install_sh())
        self.assertFalse((self.home / ".config").exists())
        self.assertIn("$ write", cap.out)


if __name__ == "__main__":
    unittest.main()
