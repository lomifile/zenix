"""Sonoma-flavoured styling.

Colours are the macOS dark-mode system values, so the popup sits in the same
palette as hypr/hyprlock.conf and waybar/waybar-style.css:

    material     rgba(30, 30, 30, 0.72)   translucent panel; hyprland's
                                          decoration.blur turns this into the
                                          Sonoma vibrancy effect
    label        #ffffff                  primaryLabelColor
    secondary    rgba(235, 235, 245, .60) secondaryLabelColor
    tertiary     rgba(235, 235, 245, .30) tertiaryLabelColor
    separator    rgba(255, 255, 255, .10) separatorColor
    accent       #0a84ff                  systemBlue (dark)
    today        #ff453a                  systemRed (dark), as in Calendar.app

SF Pro is not redistributable and is not in packages/pacman.txt, so Inter --
which is -- carries the typography. It is the closest widely available match.
"""

FONT_STACK = '"SF Pro Display", "SF Pro Text", "Inter", sans-serif'

CSS = f"""
.panel {{
    background-color: rgba(30, 30, 30, 0.72);
    border: 1px solid rgba(255, 255, 255, 0.10);
    /* matches decoration.rounding in hypr/hyprland.lua: hyprland clips the
       window at that radius, so a larger one here would simply be cut off.
       Raise both together if you want a softer corner. */
    border-radius: 12px;
}}

* {{
    font-family: {FONT_STACK};
    color: #ffffff;
}}

/* ---- month header ---- */

.month-title {{
    font-size: 15px;
    font-weight: 600;
    letter-spacing: 0.2px;
}}

.nav-button {{
    background: none;
    background-image: none;
    border: none;
    box-shadow: none;
    padding: 0 6px;
    min-width: 22px;
    min-height: 22px;
    color: rgba(235, 235, 245, 0.60);
    font-size: 15px;
}}
.nav-button:hover {{ color: #ffffff; }}
.nav-button:active {{ color: rgba(235, 235, 245, 0.30); }}

/* ---- month grid ---- */

.weekday {{
    font-size: 11px;
    font-weight: 600;
    color: rgba(235, 235, 245, 0.30);
}}

.day {{
    font-size: 13px;
    color: #ffffff;
}}

/* days spilling in from the neighbouring months */
.day-muted {{
    font-size: 13px;
    color: rgba(235, 235, 245, 0.30);
}}

/* today: filled systemRed disc, the Calendar.app treatment */
.day-today {{
    font-size: 13px;
    font-weight: 600;
    color: #ffffff;
    background-color: #ff453a;
    border-radius: 15px;
}}

/* ---- agenda ---- */

.section-title {{
    font-size: 13px;
    font-weight: 600;
    color: #ffffff;
}}

.section-subtitle {{
    font-size: 11px;
    color: rgba(235, 235, 245, 0.60);
}}

.event-rail {{
    background-color: #0a84ff;
    border-radius: 2px;
}}

.event-time {{
    font-size: 11px;
    font-weight: 500;
    color: rgba(235, 235, 245, 0.60);
}}

.event-title {{
    font-size: 13px;
    color: #ffffff;
}}

.placeholder {{
    font-size: 13px;
    color: rgba(235, 235, 245, 0.30);
}}

.separator {{
    background-color: rgba(255, 255, 255, 0.10);
}}

scrollbar {{
    background: none;
    border: none;
}}
scrollbar slider {{
    background-color: rgba(235, 235, 245, 0.20);
    border-radius: 8px;
    min-width: 4px;
}}
scrollbar slider:hover {{ background-color: rgba(235, 235, 245, 0.35); }}
""".encode()
