"""commands/webapp.py — chromeless browser windows declared as .desktop files."""

from __future__ import annotations

import unittest
from argparse import Namespace
from pathlib import Path
from unittest import mock

from tests.support import RepoCase, capture, png_bytes

from zenix import console
from zenix.commands import webapp
from zenix.console import ZenixError


class WebappCase(RepoCase):
    def setUp(self):
        super().setUp()
        self.applications = self.home / ".local" / "share" / "applications"
        self.hicolor = self.home / ".local" / "share" / "icons" / "hicolor"
        for patcher in (mock.patch.object(console, "_TTY", False),
                        mock.patch.object(webapp, "APPLICATIONS", self.applications),
                        mock.patch.object(webapp, "HICOLOR", self.hicolor),
                        mock.patch.object(webapp, "which", return_value=True)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def args(self, **kw):
        return Namespace(**{"name": None, "url": None, "title": None, "icon": None,
                            "categories": "Network;", "browser": "brave", **kw})

    def entry(self, slug="whatsapp") -> Path:
        return self.root / "webapps" / f"{slug}.desktop"

    def icon(self, slug="whatsapp") -> Path:
        return self.root / "webapps" / "icons" / f"{slug}.png"


class Slugify(unittest.TestCase):
    def test_lowercases_and_dashes(self):
        self.assertEqual(webapp.slugify("WhatsApp"), "whatsapp")
        self.assertEqual(webapp.slugify("Google Messages"), "google-messages")
        self.assertEqual(webapp.slugify("a__b"), "a-b")

    def test_trims_leading_and_trailing_separators(self):
        self.assertEqual(webapp.slugify("  Gmail!  "), "gmail")
        self.assertEqual(webapp.slugify("--x--"), "x")

    def test_keeps_digits(self):
        self.assertEqual(webapp.slugify("web2app"), "web2app")

    def test_a_name_with_nothing_usable_is_an_error(self):
        with self.assertRaises(ZenixError):
            webapp.slugify("!!!")


class PngSize(RepoCase):
    def test_reads_the_ihdr_dimensions(self):
        path = self.tmp / "icon.png"
        path.write_bytes(png_bytes(512, 512))
        self.assertEqual(webapp.png_size(path), (512, 512))

    def test_none_for_a_non_png(self):
        path = self.tmp / "icon.png"
        path.write_bytes(b"GIF89a" + b"\0" * 32)
        self.assertIsNone(webapp.png_size(path))

    def test_none_for_a_missing_file(self):
        self.assertIsNone(webapp.png_size(self.tmp / "gone.png"))


class Render(unittest.TestCase):
    def entry(self, **kw):
        defaults = dict(title="WhatsApp", url="https://web.whatsapp.com",
                        slug="whatsapp", categories="Network;", browser="brave",
                        has_icon=True)
        text = webapp.render(**{**defaults, **kw})
        return dict(line.split("=", 1) for line in text.splitlines()
                    if "=" in line and not line.startswith("["))

    def test_exec_pins_the_url_not_a_brave_app_id(self):
        fields = self.entry()
        self.assertEqual(fields["Exec"],
                         "brave --app=https://web.whatsapp.com --class=whatsapp")
        self.assertNotIn("app-id", fields["Exec"])

    def test_startupwmclass_matches_the_class(self):
        fields = self.entry()
        self.assertEqual(fields["StartupWMClass"], fields["Icon"])
        self.assertEqual(fields["StartupWMClass"], "whatsapp")

    def test_falls_back_to_the_browser_icon(self):
        self.assertEqual(self.entry(has_icon=False)["Icon"], "brave")

    def test_carries_the_zenix_marker_and_the_basics(self):
        fields = self.entry()
        self.assertEqual(fields[webapp.MARKER], "true")
        self.assertEqual(fields["Type"], "Application")
        self.assertEqual(fields["Terminal"], "false")
        self.assertEqual(fields["Categories"], "Network;")
        self.assertEqual(fields["Name"], "WhatsApp")

    def test_starts_with_the_desktop_entry_group_and_ends_with_a_newline(self):
        text = webapp.render(title="A", url="https://a", slug="a",
                             categories="Network;", browser="brave", has_icon=False)
        self.assertTrue(text.startswith("[Desktop Entry]\n"))
        self.assertTrue(text.endswith("\n"))


class ReadEntry(RepoCase):
    def test_parses_case_sensitive_keys(self):
        path = self.tmp / "x.desktop"
        path.write_text(webapp.render(title="Gmail", url="https://mail.google.com",
                                      slug="gmail", categories="Network;",
                                      browser="brave", has_icon=True))
        entry = webapp.read_entry(path)
        self.assertEqual(entry["Name"], "Gmail")
        self.assertEqual(entry["StartupWMClass"], "gmail")

    def test_a_file_without_the_group_is_empty(self):
        path = self.tmp / "x.desktop"
        path.write_text("[Other]\nName=x\n")
        self.assertEqual(webapp.read_entry(path), {})

    def test_a_file_that_is_not_ini_at_all_is_empty(self):
        path = self.tmp / "x.desktop"
        path.write_text("not a desktop file\n")
        self.assertEqual(webapp.read_entry(path), {})

    def test_undecodable_bytes_are_empty(self):
        path = self.tmp / "x.desktop"
        path.write_bytes(b"[Desktop Entry]\nName=\xff\xfe\n")
        self.assertEqual(webapp.read_entry(path), {})

    def test_url_of_reads_the_app_flag(self):
        self.assertEqual(webapp.url_of({"Exec": "brave --app=https://a.b --class=x"}),
                         "https://a.b")

    def test_url_of_is_none_without_one(self):
        self.assertIsNone(webapp.url_of({"Exec": "brave"}))
        self.assertIsNone(webapp.url_of({}))


class CmdAdd(WebappCase):
    def test_writes_the_desktop_file_into_the_repo(self):
        _, cap = capture(webapp.cmd_add, self.no_apply, self.repo,
                         self.args(name="WhatsApp", url="https://web.whatsapp.com"))
        text = self.entry().read_text()
        self.assertIn("Exec=brave --app=https://web.whatsapp.com --class=whatsapp", text)
        self.assertIn("Name=Whatsapp", text)
        self.assertIn("left alone", cap.out)

    def test_an_explicit_title_wins_over_the_slug(self):
        capture(webapp.cmd_add, self.no_apply, self.repo,
                self.args(name="whatsapp", url="https://web.whatsapp.com",
                          title="WhatsApp"))
        self.assertIn("Name=WhatsApp", self.entry().read_text())

    def test_a_non_http_url_is_refused(self):
        for url in ("web.whatsapp.com", "file:///etc/passwd", "javascript:alert(1)"):
            with self.subTest(url=url):
                with self.assertRaises(ZenixError) as caught:
                    webapp.cmd_add(self.no_apply, self.repo,
                                   self.args(name="x", url=url))
                self.assertIn("http", str(caught.exception))

    def test_an_existing_entry_is_not_overwritten(self):
        self.entry().write_text("keep me")
        with self.assertRaises(ZenixError) as caught:
            webapp.cmd_add(self.no_apply, self.repo,
                           self.args(name="whatsapp", url="https://a.b"))
        self.assertIn("already exists", str(caught.exception))
        self.assertEqual(self.entry().read_text(), "keep me")

    def test_an_icon_is_copied_in_and_referenced(self):
        src = self.tmp / "wa.png"
        src.write_bytes(png_bytes(512, 512))
        _, cap = capture(webapp.cmd_add, self.no_apply, self.repo,
                         self.args(name="whatsapp", url="https://a.b", icon=str(src)))
        self.assertTrue(self.icon().is_file())
        self.assertEqual(self.icon().stat().st_mode & 0o777, 0o644)
        self.assertIn("Icon=whatsapp", self.entry().read_text())
        self.assertNotIn("no icon given", cap.err)

    def test_an_odd_sized_icon_warns_but_is_accepted(self):
        src = self.tmp / "wa.png"
        src.write_bytes(png_bytes(128, 128))
        _, cap = capture(webapp.cmd_add, self.no_apply, self.repo,
                         self.args(name="whatsapp", url="https://a.b", icon=str(src)))
        self.assertIn("128x128", cap.err)
        self.assertTrue(self.icon().is_file())

    def test_a_non_png_icon_is_refused(self):
        src = self.tmp / "wa.jpg"
        src.write_bytes(b"\xff\xd8\xff" + b"\0" * 32)
        with self.assertRaises(ZenixError) as caught:
            capture(webapp.cmd_add, self.no_apply, self.repo,
                    self.args(name="whatsapp", url="https://a.b", icon=str(src)))
        self.assertIn("not a PNG", str(caught.exception))

    def test_a_missing_icon_path_is_refused(self):
        with self.assertRaises(ZenixError):
            capture(webapp.cmd_add, self.no_apply, self.repo,
                    self.args(name="whatsapp", url="https://a.b",
                              icon=str(self.tmp / "gone.png")))

    def test_an_icon_already_in_the_repo_is_reused(self):
        self.icon().parent.mkdir(parents=True)
        self.icon().write_bytes(png_bytes(512, 512))
        _, cap = capture(webapp.cmd_add, self.no_apply, self.repo,
                         self.args(name="whatsapp", url="https://a.b"))
        self.assertIn("reusing", cap.out)
        self.assertIn("Icon=whatsapp", self.entry().read_text())

    def test_no_icon_at_all_falls_back_to_the_browser(self):
        _, cap = capture(webapp.cmd_add, self.no_apply, self.repo,
                         self.args(name="whatsapp", url="https://a.b"))
        self.assertIn("no icon given", cap.err)
        self.assertIn("Icon=brave", self.entry().read_text())

    def test_a_missing_browser_is_flagged_but_the_entry_is_still_written(self):
        with mock.patch.object(webapp, "which", return_value=False):
            _, cap = capture(webapp.cmd_add, self.no_apply, self.repo,
                             self.args(name="whatsapp", url="https://a.b",
                                       browser="vivaldi"))
        self.assertIn("vivaldi is not installed", cap.err)
        self.assertTrue(self.entry().is_file())

    def test_dry_run_writes_nothing(self):
        src = self.tmp / "wa.png"
        src.write_bytes(png_bytes(512, 512))
        _, cap = capture(webapp.cmd_add, self.dry, self.repo,
                         self.args(name="whatsapp", url="https://a.b", icon=str(src)))
        self.assertFalse(self.entry().exists())
        self.assertFalse(self.icon().exists())
        self.assertIn("$ cp", cap.out)

    def test_applying_installs_into_the_home_directories(self):
        src = self.tmp / "wa.png"
        src.write_bytes(png_bytes(512, 512))
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        capture(webapp.cmd_add, ctx, self.repo,
                self.args(name="whatsapp", url="https://a.b", icon=str(src)))
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertIn(["install", "-m", "644", str(self.entry()),
                       str(self.applications / "whatsapp.desktop")], called)
        self.assertIn(["install", "-m", "644", str(self.icon()),
                       str(self.hicolor / "512x512" / "apps" / "whatsapp.png")], called)


class CmdRemove(WebappCase):
    def add(self, *, icon: bool = True):
        src = self.tmp / "wa.png"
        src.write_bytes(png_bytes(512, 512))
        capture(webapp.cmd_add, self.no_apply, self.repo,
                self.args(name="whatsapp", url="https://a.b",
                          icon=str(src) if icon else None))

    def test_an_unknown_app_points_at_the_list_command(self):
        with self.assertRaises(ZenixError) as caught:
            webapp.cmd_remove(self.no_apply, self.repo, self.args(name="nope"))
        self.assertIn("zenix webapp list", str(caught.exception))

    def test_removes_the_entry_and_the_icon(self):
        self.add()
        _, cap = capture(webapp.cmd_remove, self.no_apply, self.repo,
                         self.args(name="WhatsApp"))
        self.assertFalse(self.entry().exists())
        self.assertFalse(self.icon().exists())
        self.assertIn("webapps/whatsapp.desktop", cap.out)

    def test_an_app_without_an_icon_removes_cleanly(self):
        self.add(icon=False)
        capture(webapp.cmd_remove, self.no_apply, self.repo, self.args(name="whatsapp"))
        self.assertFalse(self.entry().exists())

    def test_dry_run_removes_nothing(self):
        self.add()
        _, cap = capture(webapp.cmd_remove, self.dry, self.repo,
                         self.args(name="whatsapp"))
        self.assertTrue(self.entry().is_file())
        self.assertTrue(self.icon().is_file())
        self.assertIn("$ rm", cap.out)

    def test_applying_also_uninstalls_from_home(self):
        self.add()
        installed = self.applications / "whatsapp.desktop"
        installed.parent.mkdir(parents=True)
        installed.write_text("x")
        icon = self.hicolor / "512x512" / "apps" / "whatsapp.png"
        icon.parent.mkdir(parents=True)
        icon.write_bytes(b"x")

        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        _, cap = capture(webapp.cmd_remove, ctx, self.repo, self.args(name="whatsapp"))
        self.assertFalse(installed.exists())
        self.assertFalse(icon.exists())
        self.assertIn("uninstalled", cap.out)


class CmdList(WebappCase):
    def test_nothing_declared_points_at_add(self):
        _, cap = capture(webapp.cmd_list, self.no_apply, self.repo, self.args())
        self.assertIn("zenix webapp add", cap.out)

    def test_shows_the_url_and_whether_it_is_installed(self):
        capture(webapp.cmd_add, self.no_apply, self.repo,
                self.args(name="whatsapp", url="https://web.whatsapp.com"))
        _, cap = capture(webapp.cmd_list, self.no_apply, self.repo, self.args())
        self.assertIn("https://web.whatsapp.com", cap.out)
        self.assertIn("not installed", cap.out)

        installed = self.applications / "whatsapp.desktop"
        installed.parent.mkdir(parents=True)
        installed.write_text("x")
        _, cap = capture(webapp.cmd_list, self.no_apply, self.repo, self.args())
        self.assertRegex(cap.out, r"·\s+installed")

    def test_a_missing_webapps_dir_is_not_an_error(self):
        (self.root / "webapps").rmdir()
        _, cap = capture(webapp.cmd_list, self.no_apply, self.repo, self.args())
        self.assertIn("none declared", cap.out)


class RefreshCaches(WebappCase):
    def test_runs_both_when_available(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        webapp.refresh_caches(ctx)
        called = [c.args[0][0] for c in ctx.run.call_args_list]
        self.assertEqual(called, ["update-desktop-database", "gtk-update-icon-cache"])

    def test_skips_what_is_not_installed(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        with mock.patch.object(webapp, "which", return_value=False):
            webapp.refresh_caches(ctx)
        ctx.run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
