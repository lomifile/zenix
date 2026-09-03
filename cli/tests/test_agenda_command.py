"""commands/agenda.py — the CLI over the agenda cache."""

from __future__ import annotations

import unittest
from argparse import Namespace
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

from tests.support import RepoCase, capture

from zenix import console
from zenix.commands import agenda as command
from zenix.agenda import Event


class AgendaCase(RepoCase):
    def setUp(self):
        super().setUp()
        self.cache = self.tmp / "cache" / "zenix" / "agenda.json"
        for patcher in (mock.patch.object(console, "_TTY", False),
                        mock.patch("zenix.agenda.cache_path", return_value=self.cache)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def args(self):
        return Namespace()


class CmdFetch(AgendaCase):
    def test_writes_the_cache_and_counts_the_events(self):
        with mock.patch("zenix.agenda.fetch",
                        return_value=([Event("09:30", "Standup")], None)):
            _, cap = capture(command.cmd_fetch, self.no_apply, self.repo, self.args())
        self.assertTrue(self.cache.is_file())
        self.assertIn("1 event(s)", cap.out)

    def test_an_error_is_cached_so_the_bar_can_show_it(self):
        with mock.patch("zenix.agenda.fetch", return_value=([], "gcalcli timed out")):
            _, cap = capture(command.cmd_fetch, self.no_apply, self.repo, self.args())
        self.assertTrue(self.cache.is_file())
        self.assertIn("gcalcli timed out", cap.err)
        self.assertIn("gcalcli timed out", self.cache.read_text())

    def test_dry_run_neither_fetches_nor_writes(self):
        with mock.patch("zenix.agenda.fetch") as fetch:
            _, cap = capture(command.cmd_fetch, self.dry, self.repo, self.args())
        fetch.assert_not_called()
        self.assertFalse(self.cache.exists())
        self.assertIn("would fetch", cap.out)

    def test_no_apply_still_refreshes_the_cache(self):
        """The cache is not the running system; --no-apply is about the system."""
        with mock.patch("zenix.agenda.fetch", return_value=([], None)):
            capture(command.cmd_fetch, self.no_apply, self.repo, self.args())
        self.assertTrue(self.cache.is_file())


class CmdShow(AgendaCase):
    def write(self, payload: str) -> None:
        self.cache.parent.mkdir(parents=True, exist_ok=True)
        self.cache.write_text(payload)

    def test_a_missing_cache_says_never_fetched(self):
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("fetched: never", cap.out)
        self.assertIn("no agenda cached yet", cap.err)

    def test_lists_events_with_their_times(self):
        with mock.patch("zenix.agenda.fetch",
                        return_value=([Event("09:30", "Standup"),
                                       Event("", "Holiday")], None)):
            capture(command.cmd_fetch, self.no_apply, self.repo, self.args())
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("09:30    Standup", cap.out)
        self.assertIn("All day  Holiday", cap.out)

    def test_an_empty_agenda_says_no_events(self):
        with mock.patch("zenix.agenda.fetch", return_value=([], None)):
            capture(command.cmd_fetch, self.no_apply, self.repo, self.args())
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("no events", cap.out)

    def test_reports_the_age_in_minutes(self):
        then = (datetime.now(timezone.utc) - timedelta(minutes=42)).isoformat()
        self.write('{"fetched_at": "%s", "error": null, "events": []}' % then)
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("(42 min ago)", cap.out)

    def test_a_cached_error_is_warned_about(self):
        self.write('{"fetched_at": null, "error": "not authenticated", "events": []}')
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("not authenticated", cap.err)

    def test_a_corrupt_cache_is_reported_not_raised(self):
        self.write("{ half-written")
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("unreadable cache", cap.err)

    def test_events_missing_fields_do_not_crash(self):
        self.write('{"fetched_at": null, "error": null, "events": [{}]}')
        _, cap = capture(command.cmd_show, self.no_apply, self.repo, self.args())
        self.assertIn("All day", cap.out)


class CmdPath(AgendaCase):
    def test_prints_the_bare_path_for_a_shell_to_use(self):
        _, cap = capture(command.cmd_path, self.no_apply, self.repo, self.args())
        self.assertEqual(cap.out.strip(), str(self.cache))
        self.assertEqual(cap.err, "")


if __name__ == "__main__":
    unittest.main()
