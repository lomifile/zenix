#!/usr/bin/env python3
"""Approximate what GRUB draws from theme.txt, so the design can be iterated
without rebooting. Not a parser — the geometry here mirrors theme.txt by hand,
so keep the two in step when changing the layout.

    ./preview.py [out.png]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
THEME = HERE / "theme"
INTER = "/usr/share/fonts/inter/InterVariable.ttf"

W, H = 1920, 1080
# (label, icon class or None) -- the firmware entry carries no --class, so
# grub finds no icon for it and leaves the slot empty.
ENTRIES = [("Arch Linux", "gnu-linux"),
           ("Advanced options for Arch Linux", "gnu-linux"),
           ("UEFI Firmware Settings", None)]
SELECTED = 0

MENU_LEFT, MENU_TOP, MENU_WIDTH = W // 2 - 290, int(H * 0.26), 580
ITEM_HEIGHT, ITEM_SPACING, ITEM_PADDING = 124, 6, 18
ICON, ICON_SPACE = 96, 24


def nine_slice(prefix: str, width: int, height: int) -> Image.Image:
    part = lambda n: Image.open(THEME / f"{prefix}_{n}.png").convert("RGBA")
    nw, ne, sw, se = part("nw"), part("ne"), part("sw"), part("se")
    n, s, w, e, c = part("n"), part("s"), part("w"), part("e"), part("c")

    cw, ch = nw.width, nw.height
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    mid_w, mid_h = width - cw * 2, height - ch * 2

    out.paste(nw, (0, 0)); out.paste(ne, (width - cw, 0))
    out.paste(sw, (0, height - ch)); out.paste(se, (width - cw, height - ch))
    if mid_w > 0:
        out.paste(n.resize((mid_w, ch)), (cw, 0))
        out.paste(s.resize((mid_w, ch)), (cw, height - ch))
    if mid_h > 0:
        out.paste(w.resize((cw, mid_h)), (0, ch))
        out.paste(e.resize((cw, mid_h)), (width - cw, ch))
    if mid_w > 0 and mid_h > 0:
        out.paste(c.resize((mid_w, mid_h)), (cw, ch))
    return out


def main() -> None:
    img = Image.open(THEME / "background.png").convert("RGBA")
    draw = ImageDraw.Draw(img)
    f18 = ImageFont.truetype(INTER, 20)

    y = MENU_TOP
    for i, (label, icon_class) in enumerate(ENTRIES):
        if i == SELECTED:
            img.alpha_composite(nine_slice("select", MENU_WIDTH, ITEM_HEIGHT), (MENU_LEFT, y))

        icon_x = MENU_LEFT + ITEM_PADDING
        if icon_class:
            icon = Image.open(THEME / "icons" / f"{icon_class}.png").convert("RGBA")
            img.alpha_composite(icon, (icon_x, y + (ITEM_HEIGHT - ICON) // 2))

        colour = "#ffffff" if i == SELECTED else "#98989d"
        bbox = draw.textbbox((0, 0), label, font=f18)
        draw.text((icon_x + ICON + ICON_SPACE,
                   y + (ITEM_HEIGHT - (bbox[3] - bbox[1])) / 2 - bbox[1]),
                  label, font=f18, fill=colour)
        y += ITEM_HEIGHT + ITEM_SPACING

    bar_left, bar_top, bar_w = W // 2 - 120, int(H * 0.78), 240
    draw.rectangle([bar_left, bar_top, bar_left + bar_w, bar_top + 3], fill="#2c2c2e")
    draw.rectangle([bar_left, bar_top, bar_left + int(bar_w * 0.62), bar_top + 3], fill="#f5f5f7")

    out = Path(sys.argv[1] if len(sys.argv) > 1 else "preview.png")
    img.convert("RGB").save(out)
    print(f"wrote {out} ({W}x{H})")


if __name__ == "__main__":
    main()
