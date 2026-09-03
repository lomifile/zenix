"""agenda.py — the fetch/cache split behind the waybar module."""

from __future__ import annotations

import json
import os
import subprocess
import unittest
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from zenix import agenda

HEADER = "start_date\tstart_time\tend_date\tend_time\ttitle"


class CachePath(unittest.TestCase):
    def test_honours_xdg_cache_home(self):
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": "/x/cache"}):
            self.assertEqual(agenda.cache_path(), Path("/x/cache/zenix/agenda.json"))

    def test_falls_back_to_dot_cache(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with mock.patch.object(Path, "home", return_value=Path("/home/tester")):
                self.assertEqual(agenda.cache_path(),
                                 Path("/home/tester/.cache/zenix/agenda.json"))

    def test_an_empty_xdg_cache_home_is_ignored(self):
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": ""}):
            with mock.patch.object(Path, "home", return_value=Path("/home/tester")):
                self.assertEqual(agenda.cache_path(),
                                 Path("/home/tester/.cache/zenix/agenda.json"))


class EventWhen(unittest.TestCase):
    def test_a_timed_event_shows_its_time(self):
        self.assertEqual(agenda.Event("09:30", "Standup").when, "09:30")

    def test_an_untimed_event_reads_as_all_day(self):
        self.assertEqual(agenda.Event("", "Holiday").when, "All day")

    def test_events_are_hashable_values(self):
        self.assertEqual(agenda.Event("09:30", "A"), agenda.Event("09:30", "A"))
        self.assertEqual(len({agenda.Event("09:30", "A"), agenda.Event("09:30", "A")}), 1)


class ParseTsv(unittest.TestCase):
    def test_reads_time_and_title(self):
        row = "2026-09-03\t09:30\t2026-09-03\t10:00\tStandup"
        self.assertEqual(agenda.parse_tsv(row), [agenda.Event("09:30", "Standup")])

    def test_skips_the_gcalcli_45_header(self):
        text = f"{HEADER}\n2026-09-03\t09:30\t2026-09-03\t10:00\tStandup"
        self.assertEqual(agenda.parse_tsv(text), [agenda.Event("09:30", "Standup")])

    def test_works_without_a_header(self):
        text = ("2026-09-03\t09:30\t2026-09-03\t10:00\tStandup\n"
                "2026-09-03\t14:00\t2026-09-03\t15:00\tReview")
        self.assertEqual([e.title for e in agenda.parse_tsv(text)], ["Standup", "Review"])

    def test_an_all_day_event_has_an_empty_time(self):
        row = "2026-09-03\t\t2026-09-04\t\tPublic holiday"
        self.assertEqual(agenda.parse_tsv(row), [agenda.Event("", "Public holiday")])

    def test_blank_and_short_lines_are_dropped(self):
        text = ("\n"
                "   \n"
                "2026-09-03\t09:30\ttruncated\n"
                "2026-09-03\t09:30\t2026-09-03\t10:00\tStandup\n")
        self.assertEqual(agenda.parse_tsv(text), [agenda.Event("09:30", "Standup")])

    def test_extra_columns_are_ignored(self):
        row = "2026-09-03\t09:30\t2026-09-03\t10:00\tStandup\tsome-calendar\tid"
        self.assertEqual(agenda.parse_tsv(row), [agenda.Event("09:30", "Standup")])

    def test_empty_input_is_no_events(self):
        self.assertEqual(agenda.parse_tsv(""), [])
        self.assertEqual(agenda.parse_tsv("\n\n"), [])

    def test_a_header_only_response_is_no_events(self):
        self.assertEqual(agenda.parse_tsv(HEADER), [])

    def test_an_event_titled_like_the_header_is_kept(self):
        row = "2026-09-03\t09:30\t2026-09-03\t10:00\tstart_date"
        self.assertEqual(agenda.parse_tsv(row), [agenda.Event("09:30", "start_date")])


class Fetch(unittest.TestCase):
    def done(self, code=0, stdout=""):
        return subprocess.CompletedProcess(["gcalcli"], code, stdout, "")

    def test_asks_for_an_explicit_midnight_to_midnight_range(self):
        with mock.patch("zenix.agenda.subprocess.run", return_value=self.done()) as run:
            agenda.fetch()
        cmd = run.call_args.args[0]
        today = date.today()
        self.assertEqual(cmd[:2], ["gcalcli", "agenda"])
        self.assertEqual(cmd[2], today.isoformat())
        self.assertEqual(cmd[3], (today + timedelta(days=1)).isoformat())
        self.assertIn("--tsv", cmd)
        # "today"/"tomorrow" are anchored to now, which is the bug this avoids.
        self.assertNotIn("today", cmd)

    def test_closes_stdin_so_an_unauthenticated_gcalcli_cannot_block(self):
        with mock.patch("zenix.agenda.subprocess.run", return_value=self.done()) as run:
            agenda.fetch()
        self.assertEqual(run.call_args.kwargs["stdin"], subprocess.DEVNULL)
        self.assertEqual(run.call_args.kwargs["timeout"], agenda.TIMEOUT_SECONDS)

    def test_an_explicit_span_is_passed_through(self):
        with mock.patch("zenix.agenda.subprocess.run", return_value=self.done()) as run:
            agenda.fetch(("2026-01-01", "2026-01-02"))
        self.assertEqual(run.call_args.args[0][2:4], ["2026-01-01", "2026-01-02"])

    def test_success_returns_events_and_no_error(self):
        out = f"{HEADER}\n2026-09-03\t09:30\t2026-09-03\t10:00\tStandup"
        with mock.patch("zenix.agenda.subprocess.run", return_value=self.done(stdout=out)):
            events, error = agenda.fetch()
        self.assertEqual(events, [agenda.Event("09:30", "Standup")])
        self.assertIsNone(error)

    def test_a_missing_gcalcli_is_reported_not_raised(self):
        with mock.patch("zenix.agenda.subprocess.run", side_effect=FileNotFoundError):
            events, error = agenda.fetch()
        self.assertEqual(events, [])
        self.assertEqual(error, "gcalcli is not installed")

    def test_a_timeout_is_reported(self):
        boom = subprocess.TimeoutExpired(["gcalcli"], agenda.TIMEOUT_SECONDS)
        with mock.patch("zenix.agenda.subprocess.run", side_effect=boom):
            events, error = agenda.fetch()
        self.assertEqual((events, error), ([], "gcalcli timed out"))

    def test_any_other_os_error_is_reported(self):
        with mock.patch("zenix.agenda.subprocess.run", side_effect=OSError("denied")):
            events, error = agenda.fetch()
        self.assertEqual(events, [])
        self.assertIn("denied", error)

    def test_a_non_zero_exit_reads_as_not_authenticated(self):
        with mock.patch("zenix.agenda.subprocess.run", return_value=self.done(code=1)):
            events, error = agenda.fetch()
        self.assertEqual(events, [])
        self.assertIn("gcalcli init", error)


class Cache(unittest.TestCase):
    def setUp(self):
        self._tmp = TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.cache = Path(self._tmp.name) / "zenix" / "agenda.json"
        patcher = mock.patch("zenix.agenda.cache_path", return_value=self.cache)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_write_creates_the_directory_and_returns_the_path(self):
        path = agenda.write_cache([agenda.Event("09:30", "Standup")], None)
        self.assertEqual(path, self.cache)
        self.assertTrue(self.cache.is_file())

    def test_round_trip(self):
        agenda.write_cache([agenda.Event("09:30", "Standup"),
                            agenda.Event("", "Holiday")], None)
        payload = agenda.read_cache()
        self.assertIsNone(payload["error"])
        self.assertEqual(payload["events"],
                         [{"time": "09:30", "title": "Standup"},
                          {"time": "", "title": "Holiday"}])
        self.assertIsNotNone(payload["fetched_at"])

    def test_an_error_is_cached_so_the_bar_can_show_it(self):
        agenda.write_cache([], "not authenticated")
        self.assertEqual(agenda.read_cache()["error"], "not authenticated")

    def test_no_temporary_file_is_left_behind(self):
        agenda.write_cache([], None)
        leftovers = [p.name for p in self.cache.parent.iterdir() if p.name != self.cache.name]
        self.assertEqual(leftovers, [])

    def test_the_stamp_is_utc_to_the_second(self):
        agenda.write_cache([], None)
        stamp = datetime.fromisoformat(agenda.read_cache()["fetched_at"])
        self.assertIsNotNone(stamp.tzinfo)
        self.assertEqual(stamp.microsecond, 0)

    def test_a_missing_cache_reports_rather_than_raising(self):
        payload = agenda.read_cache()
        self.assertEqual(payload["events"], [])
        self.assertEqual(payload["error"], "no agenda cached yet")
        self.assertIsNone(payload["fetched_at"])

    def test_a_corrupt_cache_reports_rather_than_raising(self):
        self.cache.parent.mkdir(parents=True)
        self.cache.write_text("{ half-written")
        payload = agenda.read_cache()
        self.assertEqual(payload["events"], [])
        self.assertIn("unreadable cache", payload["error"])

    def test_an_unreadable_cache_reports_rather_than_raising(self):
        with mock.patch.object(Path, "read_text", side_effect=OSError("EACCES")):
            payload = agenda.read_cache()
        self.assertIn("unreadable cache", payload["error"])

    def test_the_file_is_json_a_shell_script_can_read(self):
        agenda.write_cache([agenda.Event("09:30", "Standup")], None)
        text = self.cache.read_text()
        self.assertTrue(text.endswith("\n"))
        self.assertEqual(json.loads(text)["events"][0]["title"], "Standup")


class CacheAge(unittest.TestCase):
    def test_none_when_never_fetched(self):
        self.assertIsNone(agenda.cache_age_seconds({}))
        self.assertIsNone(agenda.cache_age_seconds({"fetched_at": None}))

    def test_none_for_an_unparseable_stamp(self):
        self.assertIsNone(agenda.cache_age_seconds({"fetched_at": "yesterday"}))

    def test_seconds_since_an_aware_stamp(self):
        then = datetime.now(timezone.utc) - timedelta(minutes=5)
        age = agenda.cache_age_seconds({"fetched_at": then.isoformat()})
        self.assertAlmostEqual(age, 300, delta=5)

    def test_a_naive_stamp_is_read_as_utc(self):
        then = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(minutes=5)
        age = agenda.cache_age_seconds({"fetched_at": then.isoformat()})
        self.assertAlmostEqual(age, 300, delta=5)

    def test_a_fresh_cache_is_about_zero(self):
        agenda_payload = {"fetched_at": datetime.now(timezone.utc).isoformat()}
        self.assertAlmostEqual(agenda.cache_age_seconds(agenda_payload), 0, delta=5)


if __name__ == "__main__":
    unittest.main()
