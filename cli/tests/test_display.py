from __future__ import annotations

import json
import unittest
from argparse import Namespace
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import display as display_cmd
from zenix.display import Monitor, parse_monitors, pending, plan_layout, saved_lua, to_lua

CFG = {"laptop": "eDP-1", "laptop_when_docked": "off", "scale": "auto", "monitors": {}}

LAPTOP_ON = Monitor("eDP-1", "Chimei Innolux 0x1521", disabled=False, scale=1.0)
LAPTOP_OFF = Monitor("eDP-1", "Chimei Innolux 0x1521", disabled=True, scale=1.0)
SAMSUNG = Monitor("HDMI-A-1", "Samsung Electric Company LU28R55 HNMR303699", disabled=False, scale=1.5)
DELL = Monitor("DP-2", "Dell Inc. U2720Q", disabled=False, scale=1.0)


def outputs(rules, *, disabled):
    return [r["output"] for r in rules if bool(r.get("disabled")) == disabled]


class Parse(unittest.TestCase):
    def test_reads_hyprctl_json(self):
        raw = json.dumps([
            {"name": "eDP-1", "description": "x", "disabled": True, "scale": 1.5, "width": 1920},
            {"name": "HDMI-A-1", "description": "y", "disabled": False, "scale": 1.0},
        ])
        self.assertEqual(parse_monitors(raw), [
            Monitor("eDP-1", "x", disabled=True, scale=1.5),
            Monitor("HDMI-A-1", "y", disabled=False, scale=1.0),
        ])

    def test_garbage_is_empty(self):
        self.assertEqual(parse_monitors("not json"), [])
        self.assertEqual(parse_monitors(None), [])


class PlanLayout(unittest.TestCase):
    def test_external_connected_turns_laptop_off(self):
        rules = plan_layout([LAPTOP_ON, SAMSUNG], CFG)
        self.assertEqual(outputs(rules, disabled=False), ["HDMI-A-1"])
        self.assertEqual(outputs(rules, disabled=True), ["eDP-1"])

    def test_no_external_turns_disabled_laptop_back_on(self):
        rules = plan_layout([LAPTOP_OFF], CFG)
        self.assertEqual(rules, [{"output": "eDP-1", "mode": "preferred",
                                  "position": "auto", "scale": "auto"}])

    def test_two_externals_both_enabled(self):
        rules = plan_layout([LAPTOP_ON, SAMSUNG, DELL], CFG)
        self.assertEqual(sorted(outputs(rules, disabled=False)), ["DP-2", "HDMI-A-1"])
        self.assertEqual(outputs(rules, disabled=True), ["eDP-1"])

    def test_laptop_when_docked_on_keeps_laptop(self):
        rules = plan_layout([LAPTOP_ON, SAMSUNG], {**CFG, "laptop_when_docked": "on"})
        self.assertEqual(sorted(outputs(rules, disabled=False)), ["HDMI-A-1", "eDP-1"])
        self.assertEqual(outputs(rules, disabled=True), [])

    def test_override_by_name(self):
        cfg = {**CFG, "monitors": {"HDMI-A-1": {"scale": 2}}}
        rule = next(r for r in plan_layout([SAMSUNG], cfg) if r["output"] == "HDMI-A-1")
        self.assertEqual(rule["scale"], 2)
        self.assertEqual(rule["mode"], "preferred")

    def test_override_by_description_prefix(self):
        cfg = {**CFG, "monitors": {"Samsung Electric Company LU28R55": {"scale": 1.5, "mode": "3840x2160@60"}}}
        rule = next(r for r in plan_layout([LAPTOP_ON, SAMSUNG], cfg) if r["output"] == "HDMI-A-1")
        self.assertEqual(rule["scale"], 1.5)
        self.assertEqual(rule["mode"], "3840x2160@60")

    def test_unknown_laptop_name_treats_every_output_as_external(self):
        rules = plan_layout([DELL], {**CFG, "laptop": "eDP-9"})
        self.assertEqual(outputs(rules, disabled=False), ["DP-2"])

    def test_nothing_connected_is_empty(self):
        self.assertEqual(plan_layout([], CFG), [])

    def test_enables_come_before_disables(self):
        rules = plan_layout([LAPTOP_ON, SAMSUNG], CFG)
        self.assertFalse(rules[0].get("disabled"))
        self.assertTrue(rules[-1].get("disabled"))


class Pending(unittest.TestCase):
    def test_already_correct_is_empty_in_auto_mode(self):
        monitors = [LAPTOP_OFF, SAMSUNG]
        self.assertEqual(pending(plan_layout(monitors, CFG), monitors, force=False), [])

    def test_force_reapplies_enabled_outputs_but_never_retoggles_the_laptop(self):
        monitors = [LAPTOP_OFF, SAMSUNG]
        rules = pending(plan_layout(monitors, CFG), monitors, force=True)
        self.assertEqual([r["output"] for r in rules], ["HDMI-A-1"])

    def test_disabling_an_enabled_laptop_is_pending(self):
        monitors = [LAPTOP_ON, SAMSUNG]
        rules = pending(plan_layout(monitors, CFG), monitors, force=False)
        self.assertEqual(rules, [{"output": "eDP-1", "disabled": True}])

    def test_enabling_a_disabled_laptop_is_pending(self):
        monitors = [LAPTOP_OFF]
        rules = pending(plan_layout(monitors, CFG), monitors, force=False)
        self.assertEqual([r["output"] for r in rules], ["eDP-1"])

    def test_scale_mismatch_is_pending(self):
        monitors = [LAPTOP_OFF, SAMSUNG]
        cfg = {**CFG, "monitors": {"HDMI-A-1": {"scale": 2}}}
        rules = pending(plan_layout(monitors, cfg), monitors, force=False)
        self.assertEqual([r["output"] for r in rules], ["HDMI-A-1"])


class Lua(unittest.TestCase):
    def test_disable(self):
        self.assertEqual(to_lua({"output": "eDP-1", "disabled": True}),
                         'hl.monitor({ output = "eDP-1", disabled = true })')

    def test_enable_keeps_key_order_and_numbers(self):
        self.assertEqual(
            to_lua({"output": "HDMI-A-1", "mode": "preferred", "position": "auto", "scale": 1.5}),
            'hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1.5 })',
        )

    def test_saved_file_is_a_lua_table(self):
        text = saved_lua([{"output": "eDP-1", "disabled": True}], "eDP-1")
        self.assertTrue(text.startswith("return {"))
        self.assertIn('laptop = "eDP-1"', text)
        self.assertIn('{ output = "eDP-1", disabled = true }', text)


class Command(RepoCase):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.saved = self.home / ".config" / "zenix" / "display.lua"

    def run_refresh(self, ctx, monitors, *, auto=False, running=("hyprpaper",)):
        raw = json.dumps([{"name": m.name, "description": m.description,
                           "disabled": m.disabled, "scale": m.scale} for m in monitors])
        with mock.patch.object(display_cmd, "capture", return_value=raw), \
             mock.patch.object(display_cmd, "live_hypr_instance", return_value="sig"), \
             mock.patch.object(display_cmd, "is_running", side_effect=lambda n: n in running):
            return capture(display_cmd.cmd_refresh, ctx, self.repo, Namespace(auto=auto))

    def applying(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        ctx.write.side_effect = lambda path, text: (path.parent.mkdir(parents=True, exist_ok=True),
                                                     path.write_text(text))
        return ctx

    def evals(self, ctx):
        return [c.args[0][2] for c in ctx.run.call_args_list if c.args[0][:2] == ["hyprctl", "eval"]]

    def test_docking_disables_the_laptop_via_eval(self):
        ctx = self.applying()
        self.run_refresh(ctx, [LAPTOP_ON, SAMSUNG], auto=True)
        self.assertEqual(self.evals(ctx), ['hl.monitor({ output = "eDP-1", disabled = true })'])

    def test_eval_uses_the_live_signature(self):
        ctx = self.applying()
        self.run_refresh(ctx, [LAPTOP_ON, SAMSUNG], auto=True)
        call = next(c for c in ctx.run.call_args_list if c.args[0][:2] == ["hyprctl", "eval"])
        self.assertEqual(call.kwargs["env"], {"HYPRLAND_INSTANCE_SIGNATURE": "sig"})

    def test_auto_with_nothing_to_do_runs_no_eval_and_no_waybar_reload(self):
        ctx = self.applying()
        self.run_refresh(ctx, [LAPTOP_OFF, SAMSUNG], auto=True)
        self.assertEqual(self.evals(ctx), [])
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertNotIn(["pkill", "-SIGUSR2", "waybar"], called)

    def test_manual_refresh_reloads_waybar_and_notifies(self):
        ctx = self.applying()
        self.run_refresh(ctx, [LAPTOP_OFF, SAMSUNG])
        called = [c.args[0] for c in ctx.run.call_args_list]
        self.assertIn(["pkill", "-SIGUSR2", "waybar"], called)
        self.assertTrue(any(c[0] == "notify-send" for c in called))

    def test_dead_hyprpaper_is_restarted(self):
        ctx = self.applying()
        self.run_refresh(ctx, [LAPTOP_OFF, SAMSUNG], auto=True, running=())
        self.assertIn('hl.exec_cmd("hyprpaper")', self.evals(ctx))

    def test_saves_the_layout_for_the_next_reload(self):
        ctx = self.applying()
        self.run_refresh(ctx, [LAPTOP_ON, SAMSUNG], auto=True)
        text = self.saved.read_text()
        self.assertIn('output = "eDP-1", disabled = true', text)
        self.assertIn('output = "HDMI-A-1"', text)

    def test_local_override_of_laptop_name_is_used(self):
        local = self.home / ".config" / "zenix" / "config.json"
        local.parent.mkdir(parents=True, exist_ok=True)
        local.write_text('{"display": {"laptop": "eDP-2"}}')
        ctx = self.applying()
        self.run_refresh(ctx, [Monitor("eDP-2", "panel", disabled=False), SAMSUNG], auto=True)
        self.assertEqual(self.evals(ctx), ['hl.monitor({ output = "eDP-2", disabled = true })'])

    def test_dry_run_prints_and_runs_nothing(self):
        _, cap = self.run_refresh(self.dry, [LAPTOP_ON, SAMSUNG])
        self.assertIn("hyprctl eval", cap.out)
        self.assertIn("disabled = true", cap.out)
        self.assertFalse(self.saved.exists())

    def test_no_compositor_is_an_error_message_not_a_crash(self):
        ctx = self.applying()
        with mock.patch.object(display_cmd, "capture", return_value=None), \
             mock.patch.object(display_cmd, "live_hypr_instance", return_value=None):
            _, cap = capture(display_cmd.cmd_refresh, ctx, self.repo, Namespace(auto=False))
        self.assertIn("not running", cap.all)
        ctx.run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
