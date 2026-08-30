"""A month view built by hand.

Gtk.Calendar draws its own header, week numbers and selection, none of which
can be reached from CSS, so it cannot be made to look like the Calendar.app
widget. This is a plain grid of labels instead: weekday initials, days that
spill in from neighbouring months dimmed, and today as a filled disc.
"""

from __future__ import annotations

import calendar
from datetime import date

from gi.repository import Gtk

CELL = 30          # px; .day-today's border-radius is half of this
COLUMNS = 7
ROWS = 6           # a month can straddle six ISO weeks


class MonthGrid(Gtk.Box):
    def __init__(self, today: date | None = None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self._today = today or date.today()
        self._shown = self._today.replace(day=1)
        # Monday-first, matching the locale this setup is configured for.
        self._cal = calendar.Calendar(firstweekday=0)

        self.pack_start(self._build_header(), False, False, 0)
        self._grid = Gtk.Grid(column_homogeneous=True, row_spacing=2, column_spacing=2)
        self.pack_start(self._grid, False, False, 0)

        self._render()

    # -- header ------------------------------------------------------------

    def _build_header(self) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)

        self._title = Gtk.Label(xalign=0.0)
        self._title.get_style_context().add_class("month-title")
        box.pack_start(self._title, True, True, 0)

        for glyph, delta in (("‹", -1), ("›", 1)):
            btn = Gtk.Button(label=glyph, relief=Gtk.ReliefStyle.NONE)
            btn.get_style_context().add_class("nav-button")
            btn.connect("clicked", self._shift, delta)
            box.pack_start(btn, False, False, 0)

        return box

    def _shift(self, _button, delta: int) -> None:
        month = self._shown.month + delta
        year = self._shown.year + (month - 1) // 12
        self._shown = date(year, (month - 1) % 12 + 1, 1)
        self._render()

    # -- grid --------------------------------------------------------------

    def _render(self) -> None:
        for child in self._grid.get_children():
            self._grid.remove(child)

        # calendar.month_name follows the process locale, which Gtk sets on
        # import; some locales (hr_HR among them) yield a lowercase genitive
        # form, so capitalise it the way macOS presents the month.
        month = calendar.month_name[self._shown.month].capitalize()
        self._title.set_text(f"{month} {self._shown.year}")

        # Weekday initials. %a is locale-aware; take the first letter so the
        # row stays narrow the way the macOS widget does.
        for col, day in enumerate(self._cal.iterweekdays()):
            name = calendar.day_abbr[day][:1].upper()
            label = self._cell(name, "weekday")
            self._grid.attach(label, col, 0, 1, 1)

        weeks = self._cal.monthdatescalendar(self._shown.year, self._shown.month)
        for row in range(ROWS):
            if row >= len(weeks):
                break
            for col, day in enumerate(weeks[row]):
                if day == self._today:
                    style = "day-today"
                elif day.month == self._shown.month:
                    style = "day"
                else:
                    style = "day-muted"
                self._grid.attach(self._cell(str(day.day), style), col, row + 1, 1, 1)

        self._grid.show_all()

    @staticmethod
    def _cell(text: str, style: str) -> Gtk.Label:
        label = Gtk.Label(label=text)
        label.set_size_request(CELL, CELL)
        label.get_style_context().add_class(style)
        return label
