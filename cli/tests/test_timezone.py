"""commands/timezone.py — the system timezone."""

from __future__ import annotations

import unittest
from argparse import Namespace
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import timezone
from zenix.console import ZenixError

SOME_ZONES = ["Europe/Zagreb", "Europe/Berlin", "UTC", "America/New_York"]


class TimezoneCase(RepoCase):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def args(self, **kw):
        return Namespace(**{"filter": None, "zone": None, **kw})

    def with_zones(self, zones=SOME_ZONES):
        return mock.patch.object(timezone, "zones", return_value=sorted(zones))


class Zones(TimezoneCase):
    def test_uses_zoneinfo_when_tzdata_is_present(self):
        found = timezone.zones()
        self.assertIn("UTC", found)
        self.assertEqual(found, sorted(found))

    def test_falls_back_to_timedatectl_without_tzdata(self):
        with mock.patch("zoneinfo.available_timezones", side_effect=Exception("no tzdata")):
            with mock.patch.object(timezone, "capture",
                                   return_value="Europe/Zagreb\nUTC") as cap:
                found = timezone.zones()
        cap.assert_called_once_with(["timedatectl", "list-timezones"])
        self.assertEqual(found, ["Europe/Zagreb", "UTC"])

    def test_empty_when_neither_source_answers(self):
        with mock.patch("zoneinfo.available_timezones", side_effect=Exception):
            with mock.patch.object(timezone, "capture", return_value=None):
                self.assertEqual(timezone.zones(), [])


class LiveZone(TimezoneCase):
    def test_asks_timedatectl_for_the_value_only(self):
        with mock.patch.object(timezone, "capture", return_value="UTC") as cap:
            self.assertEqual(timezone.live_zone(), "UTC")
        cap.assert_called_once_with(["timedatectl", "show", "-p", "Timezone", "--value"])

    def test_none_without_timedatectl(self):
        with mock.patch.object(timezone, "capture", return_value=None):
            self.assertIsNone(timezone.live_zone())


class CmdList(TimezoneCase):
    def test_filters_case_insensitively(self):
        with self.with_zones():
            _, cap = capture(timezone.cmd_list, self.no_apply, self.repo,
                             self.args(filter="europe"))
        self.assertIn("Europe/Zagreb", cap.out)
        self.assertNotIn("America", cap.out)

    def test_unfiltered_lists_all(self):
        with self.with_zones():
            _, cap = capture(timezone.cmd_list, self.no_apply, self.repo, self.args())
        for zone in SOME_ZONES:
            self.assertIn(zone, cap.out)

    def test_no_match_says_so(self):
        with self.with_zones():
            _, cap = capture(timezone.cmd_list, self.no_apply, self.repo,
                             self.args(filter="mars"))
        self.assertIn("no match", cap.out)


class CmdCurrent(TimezoneCase):
    def test_shows_repo_and_live(self):
        with mock.patch.object(timezone, "live_zone", return_value="UTC"):
            _, cap = capture(timezone.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("archinstall    Europe/Zagreb", cap.out)
        self.assertIn("live           UTC", cap.out)

    def test_an_unknown_live_zone_reads_as_unknown(self):
        with mock.patch.object(timezone, "live_zone", return_value=None):
            _, cap = capture(timezone.cmd_current, self.no_apply, self.repo, self.args())
        self.assertIn("live           unknown", cap.out)


class CmdSet(TimezoneCase):
    def test_writes_archinstall(self):
        with self.with_zones():
            capture(timezone.cmd_set, self.no_apply, self.repo, self.args(zone="UTC"))
        self.assertEqual(self.json()["timezone"], "UTC")
        self.assertEqual(self.json()["locale_config"]["kb_layout"], "us")

    def test_an_unknown_zone_is_refused_with_a_region_hint(self):
        with self.with_zones():
            with self.assertRaises(ZenixError) as caught:
                timezone.cmd_set(self.no_apply, self.repo,
                                 self.args(zone="Europe/Atlantis"))
        self.assertIn("zenix timezone list Europe", str(caught.exception))
        self.assertEqual(self.json()["timezone"], "Europe/Zagreb")

    def test_an_unknown_zone_list_does_not_block_a_set(self):
        with mock.patch.object(timezone, "zones", return_value=[]):
            capture(timezone.cmd_set, self.no_apply, self.repo, self.args(zone="Mars/Base"))
        self.assertEqual(self.json()["timezone"], "Mars/Base")

    def test_no_apply_stops_before_timedatectl(self):
        ctx = mock.Mock(dry_run=False, apply=False)
        with self.with_zones():
            _, cap = capture(timezone.cmd_set, ctx, self.repo, self.args(zone="UTC"))
        ctx.run.assert_not_called()
        self.assertIn("left alone", cap.out)

    def test_applying_sets_the_system_clock(self):
        ctx = mock.Mock(dry_run=False, apply=True)
        ctx.run.return_value = 0
        with self.with_zones():
            capture(timezone.cmd_set, ctx, self.repo, self.args(zone="UTC"))
        ctx.run.assert_called_once_with(["sudo", "timedatectl", "set-timezone", "UTC"])

    def test_dry_run_writes_nothing(self):
        with self.with_zones():
            capture(timezone.cmd_set, self.dry, self.repo, self.args(zone="UTC"))
        self.assertEqual(self.json()["timezone"], "Europe/Zagreb")


if __name__ == "__main__":
    unittest.main()
