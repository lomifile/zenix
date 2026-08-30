"""The popup window."""

from __future__ import annotations

from datetime import date

import gi

gi.require_version("Gtk", "3.0")

from gi.repository import Gdk, GLib, Gtk  # noqa: E402  (must follow require_version)

from calendar_popup import agenda
from calendar_popup.month_grid import MonthGrid
from calendar_popup.style import CSS

# Matched by the hl.window_rule entries in hypr/hyprland.lua.
APP_ID = "calendar-tasks"

PADDING = 20
AGENDA_WIDTH = 268
AGENDA_HEIGHT = 232


def build_panel() -> Gtk.Box:
    """The popup's content. Separate from the window so it can be rendered
    offscreen for a preview without needing a compositor."""
    panel = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=PADDING)
    panel.get_style_context().add_class("panel")
    for setter in ("set_margin_top", "set_margin_bottom",
                   "set_margin_start", "set_margin_end"):
        getattr(panel, setter)(PADDING)

    panel.pack_start(MonthGrid(), False, False, 0)

    rule = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
    rule.get_style_context().add_class("separator")
    panel.pack_start(rule, False, False, 0)

    panel.pack_start(CalendarTaskWindow._build_agenda(), True, True, 0)
    return panel


class CalendarTaskWindow(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(title="Calendar & Tasks")

        self.set_decorated(False)
        self.set_resizable(False)
        # No POPUP_MENU type hint: on Wayland that makes GDK request an
        # xdg_popup, which needs a parent surface, so a standalone window
        # never maps. Floating, pinning and placement come from the
        # hl.window_rule entries instead. set_keep_above() and set_wmclass()
        # are X11-only no-ops here for the same reason.

        # Close on focus loss, but only once the window has actually held
        # focus. hypr's input.follow_mouse = 1 means a window mapped under a
        # cursor that is still over the waybar clock may never be focused, and
        # an unguarded focus-out handler then closes the popup the instant it
        # maps — looking as though the click did nothing.
        self._had_focus = False
        self.connect("focus-in-event", self._on_focus_in)
        self.connect("focus-out-event", self._on_focus_out)
        self.connect("key-press-event", self._on_key_press)

        # The panel is translucent so hyprland's decoration.blur shows through
        # as the Sonoma vibrancy effect; that needs an RGBA visual, which also
        # keeps border-radius from being drawn over an opaque black backing.
        visual = Gdk.Screen.get_default().get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self._apply_css()
        self._build()
        self.show_all()

    # -- layout ------------------------------------------------------------

    def _build(self) -> None:
        self.add(build_panel())

    @staticmethod
    def _build_agenda() -> Gtk.Box:
        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        column.set_size_request(AGENDA_WIDTH, AGENDA_HEIGHT)

        today = date.today()
        heading = Gtk.Label(label="Today", xalign=0.0)
        heading.get_style_context().add_class("section-title")
        column.pack_start(heading, False, False, 0)

        # capitalised to match the month title; locales differ on case
        subtitle = Gtk.Label(label=today.strftime("%A, %d %B").capitalize(), xalign=0.0)
        subtitle.get_style_context().add_class("section-subtitle")
        column.pack_start(subtitle, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(AGENDA_HEIGHT)
        scroll.set_min_content_width(AGENDA_WIDTH)

        events_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        events_box.set_margin_top(10)
        for widget in CalendarTaskWindow._agenda_widgets():
            events_box.pack_start(widget, False, False, 0)

        scroll.add(events_box)
        column.pack_start(scroll, True, True, 0)
        return column

    @staticmethod
    def _agenda_widgets() -> list[Gtk.Widget]:
        try:
            events = agenda.fetch()
        except agenda.AgendaError as exc:
            return [CalendarTaskWindow._placeholder(str(exc))]

        if not events:
            return [CalendarTaskWindow._placeholder("No Events")]
        return [CalendarTaskWindow._event_row(e) for e in events]

    @staticmethod
    def _event_row(event: agenda.Event) -> Gtk.Box:
        """Accent rail, then time over title — the Calendar.app widget row."""
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        rail = Gtk.Box()
        rail.set_size_request(3, -1)
        rail.get_style_context().add_class("event-rail")
        row.pack_start(rail, False, False, 0)

        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)

        time_label = Gtk.Label(label=GLib.markup_escape_text(event.when),
                               xalign=0.0, use_markup=True)
        time_label.get_style_context().add_class("event-time")
        text.pack_start(time_label, False, False, 0)

        title = Gtk.Label(label=GLib.markup_escape_text(event.title),
                          xalign=0.0, use_markup=True)
        title.get_style_context().add_class("event-title")
        title.set_line_wrap(True)
        title.set_max_width_chars(30)
        text.pack_start(title, False, False, 0)

        row.pack_start(text, True, True, 0)
        return row

    @staticmethod
    def _placeholder(message: str) -> Gtk.Label:
        label = Gtk.Label(label=GLib.markup_escape_text(message),
                          xalign=0.0, use_markup=True)
        label.get_style_context().add_class("placeholder")
        label.set_line_wrap(True)
        label.set_max_width_chars(30)
        return label

    # -- chrome ------------------------------------------------------------

    def _on_focus_in(self, _widget, _event) -> bool:
        self._had_focus = True
        return False

    def _on_focus_out(self, _widget, _event) -> bool:
        if self._had_focus:
            self.close()
        return False

    def _on_key_press(self, _widget, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            self.close()
        return False

    @staticmethod
    def _apply_css() -> None:
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )
