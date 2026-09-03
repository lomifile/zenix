"""commands/keyboard.py — layout, written to both the desktop and archinstall."""

from __future__ import annotations

import unittest
from argparse import Namespace
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import keyboard
from zenix.console import ZenixError

RULES = """! model
  pc105           Generic 105-key PC

! layout
  us              English (US)
  hr              Croatian
  de              German

! variant
  dvorak          us: English (Dvorak)
"""


class KeyboardCase(RepoCase):
    def setUp(self):
        super().setUp()
        self.rules = self.tmp / "base.lst"
        self.rules.write_text(RULES)
        for patcher in (mock.patch.object(console, "_TTY", False),
                        mock.patch.object(keyboard, "XKB_RULES", self.rules)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def args(self, **kw):
        return Namespace(**{"filter": None, "layout": None, "variant": None, **kw})


class Layouts(KeyboardCase):
    def test_reads_only_the_layout_section(self):
        found = keyboard.layouts()
        self.assertEqual(found, {"us": "English (US)", "hr": "Croatian", "de": "German"})

    def test_no_rules_file_is_empty_not_an_error(self):
        self.rules.unlink()
        self.assertEqual(keyboard.layouts(), {})

    def test_undecodable_bytes_do_not_raise(self):
        self.rules.write_bytes(b"! layout\n  us  English \xff(US)\n")
        self.assertIn("us", keyboard.layouts())


class CmdList(KeyboardCase):
    def test_lists_everything_unfiltered(self):
        _, cap = capture(keyboard.cmd_list, self.no_apply, self.repo, self.args())
        for code in ("us", "hr", "de"):
            self.assertIn(code, cap.out)

    def test_filters_on_code_or_description_case_insensitively(self):
        _, cap = capture(keyboard.cmd_list, self.no_apply, self.repo,
                         self.args(filter="CROAT"))
        self.assertIn("hr", cap.out)
        self.assertNotIn("German", cap.out)

    def test_no_match_says_so(self):
        _, cap = capture(keyboard.cmd_list, self.no_apply, self.repo,
                         self.args(filter="klingon"))
        self.assertIn("no match", cap.out)

    def test_a_missing_rules_file_names_the_package(self):
        self.rules.unlink()
        with self.assertRaises(ZenixError) as caught:
            keyboard.cmd_list(self.no_apply, self.repo, self.args())
        self.assertIn("xkeyboard-config", str(caught.exception))


class CmdCurrent(KeyboardCase):
    def test_shows_repo_and_live(self):
        with mock.patch.object(keyboard, "capture",
                               return_value="Keymap: us\nX11 Layout: us"):
            _, cap = capture(keyboard.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("hyprland.lua   us", cap.out)
        self.assertIn("variant: -", cap.out)
        self.assertIn("archinstall    us", cap.out)
        self.assertIn("live           Keymap: us", cap.out)

    def test_survives_a_missing_localectl(self):
        with mock.patch.object(keyboard, "capture", return_value=None):
            _, cap = capture(keyboard.cmd_current, self.no_apply, self.repo, self.args())
        self.assertNotIn("live", cap.out)


class CmdSet(KeyboardCase):
    def test_an_unknown_layout_is_refused_with_a_hint(self):
        with self.assertRaises(ZenixError) as caught:
            keyboard.cmd_set(self.no_apply, self.repo, self.args(layout="klingon"))
        self.assertIn("zenix keyboard list kl", str(caught.exception))

    def test_writes_hyprland_and_archinstall_together(self):
        capture(keyboard.cmd_set, self.no_apply, self.repo, self.args(layout="hr"))
        self.assertEqual(self.repo.read_lua_field("kb_layout"), "hr")
        self.assertEqual(self.json()["locale_config"]["kb_layout"], "hr")

    def test_a_variant_is_inserted_next_to_the_layout(self):
        capture(keyboard.cmd_set, self.no_apply, self.repo,
                self.args(layout="us", variant="dvorak"))
        self.assertEqual(self.repo.read_lua_field("kb_variant"), "dvorak")

    def test_an_empty_variant_clears_it(self):
        capture(keyboard.cmd_set, self.no_apply, self.repo,
                self.args(layout="us", variant="dvorak"))
        _, cap = capture(keyboard.cmd_set, self.no_apply, self.repo,
                         self.args(layout="us", variant=""))
        self.assertEqual(self.repo.read_lua_field("kb_variant"), "")
        self.assertIn("(cleared)", cap.out)

    def test_no_variant_leaves_the_existing_one_untouched(self):
        capture(keyboard.cmd_set, self.no_apply, self.repo,
                self.args(layout="us", variant="dvorak"))
        capture(keyboard.cmd_set, self.no_apply, self.repo, self.args(layout="hr"))
        self.assertEqual(self.repo.read_lua_field("kb_variant"), "dvorak")

    def test_other_archinstall_keys_survive(self):
        capture(keyboard.cmd_set, self.no_apply, self.repo, self.args(layout="hr"))
        data = self.json()
        self.assertEqual(data["locale_config"]["sys_lang"], "en_US.UTF-8")
        self.assertEqual(data["timezone"], "Europe/Zagreb")

    def test_a_missing_locale_config_is_created(self):
        data, trailing = self.repo.load_archinstall()
        del data["locale_config"]
        self.repo.save_archinstall(self.no_apply, data, trailing)
        capture(keyboard.cmd_set, self.no_apply, self.repo, self.args(layout="hr"))
        self.assertEqual(self.json()["locale_config"], {"kb_layout": "hr"})

    def test_no_apply_stops_before_localectl(self):
        ctx = mock.Mock(dry_run=False, apply=False)
        _, cap = capture(keyboard.cmd_set, ctx, self.repo, self.args(layout="hr"))
        ctx.run.assert_not_called()
        self.assertIn("left alone", cap.out)

    def test_applying_reloads_hyprland_and_localectl(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        with mock.patch.object(keyboard, "which", return_value=True):
            capture(keyboard.cmd_set, ctx, self.repo,
                    self.args(layout="hr", variant="dvorak"))
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertIn(["hyprctl", "keyword", "input:kb_layout", "hr"], called)
        self.assertIn(["hyprctl", "keyword", "input:kb_variant", "dvorak"], called)
        self.assertIn(["sudo", "localectl", "set-x11-keymap", "hr", "", "dvorak"], called)
        self.assertIn(["sudo", "localectl", "set-keymap", "hr"], called)

    def test_localectl_still_runs_without_hyprland(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        with mock.patch.object(keyboard, "which", return_value=False):
            capture(keyboard.cmd_set, ctx, self.repo, self.args(layout="hr"))
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertNotIn("hyprctl", [c[0] for c in called])
        self.assertIn(["sudo", "localectl", "set-keymap", "hr"], called)

    def test_an_unset_variant_is_passed_to_localectl_as_empty(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        with mock.patch.object(keyboard, "which", return_value=False):
            capture(keyboard.cmd_set, ctx, self.repo, self.args(layout="hr"))
        self.assertIn(["sudo", "localectl", "set-x11-keymap", "hr", "", ""],
                      [c.args[0] for c in ctx.run.call_args_list])

    def test_an_unreadable_rules_file_does_not_block_a_set(self):
        self.rules.unlink()
        capture(keyboard.cmd_set, self.no_apply, self.repo, self.args(layout="anything"))
        self.assertEqual(self.repo.read_lua_field("kb_layout"), "anything")

    def test_dry_run_writes_nothing(self):
        capture(keyboard.cmd_set, self.dry, self.repo, self.args(layout="hr"))
        self.assertEqual(self.repo.read_lua_field("kb_layout"), "us")
        self.assertEqual(self.json()["locale_config"]["kb_layout"], "us")


if __name__ == "__main__":
    unittest.main()
