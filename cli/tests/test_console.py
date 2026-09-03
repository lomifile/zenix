"""console.py — the output vocabulary shared with install.sh."""

from __future__ import annotations

import unittest
from unittest import mock

from tests.support import capture

from zenix import console


class Paint(unittest.TestCase):
    def test_wraps_in_the_escape_code_on_a_tty(self):
        with mock.patch.object(console, "_TTY", True):
            self.assertEqual(console.paint("32", "hi"), "\033[32mhi\033[0m")

    def test_passes_text_through_when_redirected(self):
        with mock.patch.object(console, "_TTY", False):
            self.assertEqual(console.paint("32", "hi"), "hi")


class Streams(unittest.TestCase):
    """Warnings go to stderr so a piped `zenix ... | ...` still shows them."""

    def setUp(self):
        patcher = mock.patch.object(console, "_TTY", False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_header_is_blank_line_then_arrow(self):
        _, cap = capture(console.header, "Doing a thing")
        self.assertEqual(cap.out, "\n==> Doing a thing\n")
        self.assertEqual(cap.err, "")

    def test_info_and_ok_and_dim_go_to_stdout_indented(self):
        for fn, expected in ((console.info, "    plain\n"),
                             (console.ok, "    ✓ plain\n"),
                             (console.dim, "    plain\n")):
            with self.subTest(fn=fn.__name__):
                _, cap = capture(fn, "plain")
                self.assertEqual(cap.out, expected)
                self.assertEqual(cap.err, "")

    def test_warn_goes_to_stderr(self):
        _, cap = capture(console.warn, "careful")
        self.assertEqual(cap.out, "")
        self.assertEqual(cap.err, "    ! careful\n")


class Die(unittest.TestCase):
    def test_raises_zenix_error_with_the_message(self):
        with self.assertRaises(console.ZenixError) as caught:
            console.die("no such thing")
        self.assertEqual(str(caught.exception), "no such thing")


if __name__ == "__main__":
    unittest.main()
