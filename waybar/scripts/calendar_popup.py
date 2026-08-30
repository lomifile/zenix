#!/usr/bin/env python3
import gi
import subprocess

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk


class CalendarTaskWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Calendar & Tasks")
        # Set window class for window rules (like Hyprland)
        self.set_wmclass("calendar-tasks", "calendar-tasks")

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)

        # Close window if it loses focus
        self.connect("focus-out-event", lambda w, e: self.close())

        self.apply_css()

        # Main horizontal layout (2 columns)
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        main_box.set_margin_top(16)
        main_box.set_margin_bottom(16)
        main_box.set_margin_start(16)
        main_box.set_margin_end(16)
        self.add(main_box)

        # Left Column: Calendar
        cal_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.calendar = Gtk.Calendar()
        cal_box.pack_start(self.calendar, True, True, 0)
        main_box.pack_start(cal_box, False, False, 0)

        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        main_box.pack_start(sep, False, False, 0)

        # Right Column: Tasks/Agenda Overview
        task_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        task_label = Gtk.Label(label="<b>Google Calendar Agenda</b>", use_markup=True)
        task_label.set_halign(Gtk.Align.START)
        task_box.pack_start(task_label, False, False, 0)

        # Scrollable area for events
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(200)
        scroll.set_min_content_width(250)

        event_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        scroll.add(event_list)
        task_box.pack_start(scroll, True, True, 0)

        # Fetch and populate tasks
        tasks = self.get_tasks()
        for t in tasks:
            row_label = Gtk.Label(label=t)
            row_label.set_halign(Gtk.Align.START)
            row_label.set_line_wrap(True)
            event_list.pack_start(row_label, False, False, 0)

        main_box.pack_start(task_box, True, True, 0)
        self.show_all()

    def get_tasks(self):
        try:
            # Fetch today's agenda using gcalcli in TSV format
            result = subprocess.run(
                ["gcalcli", "agenda", "today", "tomorrow", "--tsv"],
                capture_output=True,
                text=True,
            )

            if result.returncode != 0:
                return ["Authentication required.", "Run 'gcalcli agenda' in terminal."]

            events = []
            for line in result.stdout.strip().split("\n"):
                if line.strip():
                    parts = line.split("\t")
                    if len(parts) >= 5:
                        time = parts[1]
                        title = parts[4]
                        display_text = (
                            f"• <b>{time}</b>  {title}"
                            if time
                            else f"• <b>All Day</b>  {title}"
                        )
                        events.append(display_text)

            return events if events else ["No events today!"]

        except FileNotFoundError:
            return ["gcalcli is not installed."]
        except Exception as e:
            return ["Error loading calendar."]

    def apply_css(self):
        css = b"""
        window {
            background-color: rgba(28, 28, 30, 0.96);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 14px;
        }
        label, calendar {
            color: #f5f5f7;
            font-family: "JetBrainsMono Nerd Font", "Inter", sans-serif;
            font-size: 13px;
        }
        calendar {
            background-color: transparent;
        }
        calendar:selected {
            background-color: #0a84ff;
            color: #ffffff;
            border-radius: 8px;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )


if __name__ == "__main__":
    win = CalendarTaskWindow()
    win.connect("destroy", Gtk.main_quit)
    Gtk.main()
