from __future__ import annotations

import json
import unittest
from argparse import Namespace
from datetime import date, datetime, timedelta
from unittest import mock
from zoneinfo import ZoneInfo

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import nightlight as nl_cmd
from zenix.nightlight import (
    Override,
    effective_override,
    next_boundary,
    night_window,
    sun_times,
    target_temp,
    toggle_override,
)

ZAGREB = ZoneInfo("Europe/Zagreb")

CUSTOM = {
    "mode": "custom", "day_temp": 6500, "night_temp": 4500,
    "start": "20:00", "end": "07:00", "transition_minutes": 30,
    "latitude": 45.81, "longitude": 15.98,
}


def at(hh: int, mm: int = 0, day: date = date(2026, 11, 13)) -> datetime:
    return datetime(day.year, day.month, day.day, hh, mm, tzinfo=ZAGREB)


class Custom(unittest.TestCase):
    def test_deep_night_is_night_temp(self):
        self.assertEqual(target_temp(CUSTOM, at(21)), 4500)
        self.assertEqual(target_temp(CUSTOM, at(3)), 4500)

    def test_midday_is_day_temp(self):
        self.assertEqual(target_temp(CUSTOM, at(12)), 6500)

    def test_evening_ramp_midpoint(self):
        self.assertEqual(target_temp(CUSTOM, at(20, 15)), 5500)

    def test_morning_ramp_is_between(self):
        self.assertEqual(target_temp(CUSTOM, at(6, 45)), 5500)
        self.assertEqual(target_temp(CUSTOM, at(7)), 6500)

    def test_window_crosses_midnight(self):
        start, end = night_window(CUSTOM, at(23))
        self.assertEqual(start, at(20))
        self.assertEqual(end, at(7, day=date(2026, 11, 14)))

    def test_after_midnight_belongs_to_yesterdays_window(self):
        start, end = night_window(CUSTOM, at(2))
        self.assertEqual(start, at(20, day=date(2026, 11, 12)))
        self.assertEqual(end, at(7))

    def test_daytime_points_at_tonight(self):
        start, _ = night_window(CUSTOM, at(12))
        self.assertEqual(start, at(20))

    def test_same_day_window(self):
        cfg = {**CUSTOM, "start": "13:00", "end": "15:00", "transition_minutes": 0}
        self.assertEqual(target_temp(cfg, at(14)), 4500)
        self.assertEqual(target_temp(cfg, at(16)), 6500)

    def test_zero_transition_is_a_step(self):
        cfg = {**CUSTOM, "transition_minutes": 0}
        self.assertEqual(target_temp(cfg, at(19, 59)), 6500)
        self.assertEqual(target_temp(cfg, at(20)), 4500)

    def test_short_window_never_reaches_full_night(self):
        cfg = {**CUSTOM, "start": "20:00", "end": "20:20", "transition_minutes": 30}
        value = target_temp(cfg, at(20, 10))
        self.assertTrue(4500 < value < 6500)

    def test_mode_off_is_day(self):
        self.assertEqual(target_temp({**CUSTOM, "mode": "off"}, at(23)), 6500)
        self.assertIsNone(night_window({**CUSTOM, "mode": "off"}, at(23)))

    def test_bad_time_falls_back_to_defaults(self):
        cfg = {**CUSTOM, "start": "nonsense"}
        self.assertEqual(target_temp(cfg, at(21)), 4500)


class Sun(unittest.TestCase):
    def test_zagreb_midsummer_sunset(self):
        sunrise, sunset = sun_times(date(2026, 6, 21), 45.81, 15.98, ZAGREB)
        expected = datetime(2026, 6, 21, 20, 50, tzinfo=ZAGREB)
        self.assertLess(abs(sunset - expected), timedelta(minutes=5))
        self.assertLess(abs(sunrise - datetime(2026, 6, 21, 5, 6, tzinfo=ZAGREB)), timedelta(minutes=5))

    def test_polar_day_has_no_sunset(self):
        self.assertIsNone(sun_times(date(2026, 6, 21), 78.0, 15.0, ZAGREB))

    def test_polar_day_stays_at_day_temp(self):
        cfg = {**CUSTOM, "mode": "sun", "latitude": 78.0, "longitude": 15.0}
        self.assertEqual(target_temp(cfg, at(23, day=date(2026, 6, 21))), 6500)

    def test_sun_mode_is_night_after_sunset(self):
        cfg = {**CUSTOM, "mode": "sun"}
        self.assertEqual(target_temp(cfg, at(23, day=date(2026, 6, 21))), 4500)
        self.assertEqual(target_temp(cfg, at(13, day=date(2026, 6, 21))), 6500)

    def test_sun_window_runs_sunset_to_next_sunrise(self):
        cfg = {**CUSTOM, "mode": "sun"}
        start, end = night_window(cfg, at(23, day=date(2026, 6, 21)))
        self.assertEqual(start.date(), date(2026, 6, 21))
        self.assertEqual(end.date(), date(2026, 6, 22))
        self.assertLess(end.hour, 7)


class Overrides(unittest.TestCase):
    def test_on_during_day_is_night_temp(self):
        self.assertEqual(target_temp(CUSTOM, at(12), Override("on", None)), 4500)

    def test_off_during_night_is_day_temp(self):
        self.assertEqual(target_temp(CUSTOM, at(23), Override("off", None)), 6500)

    def test_expired_override_is_ignored(self):
        o = Override("on", at(13))
        self.assertIsNone(effective_override(o, at(14)))
        self.assertEqual(effective_override(o, at(12)), o)

    def test_toggle_in_day_turns_on_until_tonights_ramp_completes(self):
        o = toggle_override(CUSTOM, at(12), None)
        self.assertEqual(o, Override("on", at(20, 30)))

    def test_toggle_at_night_turns_off_until_morning(self):
        o = toggle_override(CUSTOM, at(23), None)
        self.assertEqual(o, Override("off", at(7, day=date(2026, 11, 14))))

    def test_toggle_twice_returns_to_schedule(self):
        first = toggle_override(CUSTOM, at(12), None)
        self.assertIsNone(toggle_override(CUSTOM, at(12), first))

    def test_toggle_without_schedule_is_indefinite(self):
        o = toggle_override({**CUSTOM, "mode": "off"}, at(12), None)
        self.assertEqual(o, Override("on", None))

    def test_next_boundary(self):
        self.assertEqual(next_boundary(CUSTOM, at(12)), at(20))
        self.assertEqual(next_boundary(CUSTOM, at(23)), at(7, day=date(2026, 11, 14)))


class Command(RepoCase):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)
        cfg = json.loads(self.repo.zenix_json.read_text())
        cfg["nightlight"] = CUSTOM
        self.repo.zenix_json.write_text(json.dumps(cfg))
        self.state = self.home / ".local" / "state" / "zenix" / "nightlight.json"

    def ctx(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        ctx.write.side_effect = lambda path, text: (path.parent.mkdir(parents=True, exist_ok=True),
                                                     path.write_text(text))
        return ctx

    def run_action(self, action, now):
        ctx = self.ctx()
        with mock.patch.object(nl_cmd, "now", return_value=now), \
             mock.patch.object(nl_cmd, "live_hypr_instance", return_value="sig"):
            _, cap = capture(nl_cmd.cmd_action, ctx, self.repo, Namespace(action=action))
        return ctx, cap

    def sent(self, ctx):
        return [c.args[0] for c in ctx.run.call_args_list if c.args[0][:2] == ["hyprctl", "hyprsunset"]]

    def test_on_writes_state_and_applies_now(self):
        ctx, _ = self.run_action("on", at(12))
        self.assertEqual(json.loads(self.state.read_text())["value"], "on")
        self.assertEqual(self.sent(ctx), [["hyprctl", "hyprsunset", "temperature", "4500"]])

    def test_off_at_night_sends_identity(self):
        ctx, _ = self.run_action("off", at(23))
        self.assertEqual(self.sent(ctx), [["hyprctl", "hyprsunset", "identity"]])

    def test_auto_clears_the_override(self):
        self.run_action("on", at(12))
        ctx, _ = self.run_action("auto", at(12))
        self.assertFalse(self.state.exists())
        self.assertEqual(self.sent(ctx), [["hyprctl", "hyprsunset", "identity"]])

    def test_toggle_flips_and_reports(self):
        _, cap = self.run_action("toggle", at(12))
        self.assertIn("on", cap.out)
        self.assertIn("20:30", cap.out)

    def test_status_reports_schedule(self):
        _, cap = self.run_action("status", at(21))
        self.assertIn("4500", cap.out)
        self.assertIn("custom", cap.out)

    def test_corrupt_state_is_ignored(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text("{ nope")
        ctx, _ = self.run_action("status", at(12))
        self.assertEqual(ctx.run.call_count, 0)


class Daemon(RepoCase):
    def setUp(self):
        super().setUp()
        cfg = json.loads(self.repo.zenix_json.read_text())
        cfg["nightlight"] = CUSTOM
        self.repo.zenix_json.write_text(json.dumps(cfg))

    def test_tick_applies_only_on_change(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        with mock.patch.object(nl_cmd, "live_hypr_instance", return_value="sig"):
            last, wait = nl_cmd.tick(ctx, self.repo, at(21), None)
            self.assertEqual(last, 4500)
            self.assertEqual(wait, 60)
            last, _ = nl_cmd.tick(ctx, self.repo, at(21, 1), last)
        self.assertEqual(ctx.run.call_count, 1)

    def test_tick_polls_fast_while_ramping(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        with mock.patch.object(nl_cmd, "live_hypr_instance", return_value="sig"):
            _, wait = nl_cmd.tick(ctx, self.repo, at(20, 10), None)
        self.assertEqual(wait, 10)

    def test_failed_send_is_retried_next_tick(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 1
        with mock.patch.object(nl_cmd, "live_hypr_instance", return_value="sig"):
            last, _ = nl_cmd.tick(ctx, self.repo, at(21), None)
        self.assertIsNone(last)

    def test_no_compositor_waits(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        with mock.patch.object(nl_cmd, "live_hypr_instance", return_value=None):
            last, wait = nl_cmd.tick(ctx, self.repo, at(21), 4500)
        self.assertIsNone(last)
        ctx.run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
