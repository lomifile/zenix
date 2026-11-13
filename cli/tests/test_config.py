from __future__ import annotations

import json
import unittest
from argparse import Namespace
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import config as config_cmd
from zenix.config import Config, deep_merge, parse_value
from zenix.console import ZenixError


class ConfigCase(RepoCase):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.local = self.home / ".config" / "zenix" / "config.json"

    def write_local(self, data) -> None:
        self.local.parent.mkdir(parents=True, exist_ok=True)
        self.local.write_text(data if isinstance(data, str) else json.dumps(data))


class Merge(unittest.TestCase):
    def test_nested_override_keeps_siblings(self):
        base = {"display": {"laptop": "eDP-1", "scale": "auto"}, "theme": "a"}
        merged = deep_merge(base, {"display": {"scale": 1.5}})
        self.assertEqual(merged, {"display": {"laptop": "eDP-1", "scale": 1.5}, "theme": "a"})
        self.assertEqual(base["display"]["scale"], "auto")

    def test_scalar_replaces_dict(self):
        self.assertEqual(deep_merge({"a": {"b": 1}}, {"a": 2}), {"a": 2})

    def test_parse_value(self):
        self.assertEqual(parse_value("0.85"), 0.85)
        self.assertEqual(parse_value("true"), True)
        self.assertEqual(parse_value('{"a": 1}'), {"a": 1})
        self.assertEqual(parse_value("20:00"), "20:00")


class Load(ConfigCase):
    def test_missing_local_uses_repo_values(self):
        cfg = Config.load(self.repo)
        self.assertEqual(cfg.get("theme"), "fixture")
        self.assertEqual(cfg.get("display.laptop"), "eDP-1")
        self.assertEqual(cfg.source("theme"), "repo")

    def test_local_overrides_nested_keys_only(self):
        self.write_local({"display": {"scale": 1.5}})
        cfg = Config.load(self.repo)
        self.assertEqual(cfg.get("display.scale"), 1.5)
        self.assertEqual(cfg.get("display.laptop"), "eDP-1")
        self.assertEqual(cfg.source("display.scale"), "local")
        self.assertEqual(cfg.source("display.laptop"), "repo")

    def test_invalid_local_json_names_the_file(self):
        self.write_local("{ nope")
        with self.assertRaises(ZenixError) as caught:
            Config.load(self.repo)
        self.assertIn(str(self.local), str(caught.exception))
        self.assertIn("invalid JSON", str(caught.exception))

    def test_invalid_repo_json_names_the_file(self):
        self.repo.zenix_json.write_text("[1, 2")
        with self.assertRaises(ZenixError) as caught:
            Config.load(self.repo)
        self.assertIn("zenix.json", str(caught.exception))

    def test_unknown_key_falls_back_to_default(self):
        cfg = Config.load(self.repo)
        self.assertIsNone(cfg.get("nope.deeper"))
        self.assertEqual(cfg.get("nope", 3), 3)


class Set(ConfigCase):
    def args(self, key, value, local=False):
        return Namespace(key=key, value=value, local=local)

    def test_set_local_leaves_repo_unchanged(self):
        before = self.repo.zenix_json.read_text()
        capture(config_cmd.cmd_set, self.live, self.repo, self.args("display.scale", "1.5", local=True))
        self.assertEqual(self.repo.zenix_json.read_text(), before)
        self.assertEqual(json.loads(self.local.read_text()), {"display": {"scale": 1.5}})

    def test_set_repo_writes_typed_value(self):
        capture(config_cmd.cmd_set, self.live, self.repo, self.args("waybar.opacity", "0.85"))
        self.assertEqual(self.config()["waybar"]["opacity"], 0.85)
        self.assertEqual(self.config()["waybar"]["height"], 32)
        self.assertFalse(self.local.exists())

    def test_set_creates_missing_sections(self):
        capture(config_cmd.cmd_set, self.live, self.repo, self.args("nightlight.start", "20:00"))
        self.assertEqual(self.config()["nightlight"], {"start": "20:00"})

    def test_dry_run_writes_nothing(self):
        before = self.repo.zenix_json.read_text()
        _, cap = capture(config_cmd.cmd_set, self.dry, self.repo, self.args("theme", "x"))
        self.assertEqual(self.repo.zenix_json.read_text(), before)
        self.assertIn("$ write", cap.out)

    def test_file_keeps_trailing_newline(self):
        capture(config_cmd.cmd_set, self.live, self.repo, self.args("theme", "x"))
        self.assertTrue(self.repo.zenix_json.read_text().endswith("}\n"))


class SetWaybar(ConfigCase):
    def setUp(self):
        super().setUp()
        (self.root / "waybar").mkdir(exist_ok=True)
        self.css = self.root / "waybar" / "waybar-style.css"
        self.css.write_text("/* >>> zenix theme <<< */\nold\n/* >>> end zenix theme <<< */\n")

    def test_setting_opacity_rewrites_the_bar_css_and_reloads_waybar(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        ctx.write.side_effect = lambda path, text: path.write_text(text)
        with mock.patch.object(config_cmd, "which", return_value=True):
            capture(config_cmd.cmd_set, ctx, self.repo, Namespace(key="waybar.opacity", value="0.85", local=False))
        self.assertIn("@define-color bar-bg rgba(72, 56, 56, 0.85);", self.css.read_text())
        self.assertIn(["pkill", "-SIGUSR2", "waybar"], [c.args[0] for c in ctx.run.call_args_list])

    def test_non_waybar_keys_leave_the_css_alone(self):
        before = self.css.read_text()
        capture(config_cmd.cmd_set, self.live, self.repo, Namespace(key="display.scale", value="2", local=True))
        self.assertEqual(self.css.read_text(), before)


class Show(ConfigCase):
    def test_get_prints_value(self):
        _, cap = capture(config_cmd.cmd_get, self.live, self.repo, Namespace(key="wallpaper.desktop"))
        self.assertEqual(cap.out.strip(), "desk.png")

    def test_get_unknown_is_error(self):
        with self.assertRaises(ZenixError):
            capture(config_cmd.cmd_get, self.live, self.repo, Namespace(key="nope"))

    def test_show_source_tags_local(self):
        self.write_local({"display": {"scale": 1.5}})
        _, cap = capture(config_cmd.cmd_show, self.live, self.repo, Namespace(source=True))
        line = next(l for l in cap.out.splitlines() if "display.scale" in l)
        self.assertIn("local", line)
        line = next(l for l in cap.out.splitlines() if "display.laptop" in l)
        self.assertIn("repo", line)


if __name__ == "__main__":
    unittest.main()
