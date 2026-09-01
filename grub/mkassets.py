#!/usr/bin/env python3
"""Generate the theme's PNGs.

The reference is the macOS Startup Manager, which is: a flat near-black
ground, a large disk icon per entry, generous negative space, and a selection
that is a soft fill rather than a button. No gradients, no colour, no
keyboard hints -- those read as a Linux theme, not a Mac one.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "theme")
W, H = 1920, 1080

GROUND = (0x14, 0x14, 0x16)
LIFT = (0x1E, 0x1E, 0x22)          # barely-there centre lift, not a gradient

SELECT_RADIUS = 12
SELECT_FILL = (255, 255, 255, 20)  # ~8%; no border, macOS selections have none

ICON = 96
# Entry classes grub-mkconfig emits for Linux entries; all get the same drive.
ICON_CLASSES = ("gnu-linux", "gnu", "os")


def background() -> None:
    """A single smooth vertical ramp.

    An earlier version blurred an ellipse, which left visible banding and
    mottling on a near-black ground. Computing the ramp per scanline avoids
    both, and a flat-ish field is what the Startup Manager actually shows.
    """
    base = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(base)
    for y in range(H):
        t = y / (H - 1)
        # brightest a third of the way down, behind the menu, then falling away
        k = 1.0 - abs(t - 0.34) / 0.66
        k = max(0.0, k) ** 1.6
        d.line([(0, y), (W, y)],
               fill=tuple(round(g + (l - g) * k) for g, l in zip(GROUND, LIFT)))
    base.save(OUT / "background.png")


def drive_icon() -> Image.Image:
    """A silver internal disk, straight on -- the Startup Manager's motif.

    Supersampled and downscaled so the corners stay clean, with a drop shadow
    so it sits on the dark ground instead of floating flat against it.
    """
    scale = 4
    size = ICON * scale
    pad = int(size * 0.06)
    body = [pad, int(size * 0.16), size - pad, size - int(size * 0.10)]
    radius = int(size * 0.10)

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # shadow first, underneath everything
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [body[0], body[1] + int(size * 0.05), body[2], body[3] + int(size * 0.05)],
        radius=radius, fill=(0, 0, 0, 130))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.035)))

    # silver body
    grad = Image.new("RGB", (1, size))
    gd = ImageDraw.Draw(grad)
    top, bottom = (0xE4, 0xE4, 0xE8), (0x7A, 0x7A, 0x82)
    for y in range(size):
        t = y / (size - 1)
        gd.point((0, y), fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    grad = grad.resize((size, size))

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(body, radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    # a brighter top face, so it reads as a physical drive rather than a square
    face = [body[0], body[1], body[2], body[1] + int((body[3] - body[1]) * 0.30)]
    face_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(face_mask).rounded_rectangle(face, radius=radius, fill=70)
    img.paste(Image.new("RGB", (size, size), (255, 255, 255)), (0, 0), face_mask)

    # definition against the dark ground
    d.rounded_rectangle(body, radius=radius, outline=(255, 255, 255, 120),
                        width=max(2, scale // 2))

    return img.resize((ICON, ICON), Image.LANCZOS)


def nine_slice(prefix: str, radius: int, fill, edge=None) -> None:
    """Emit the *_c/_n/_s/_e/_w/_nw/_ne/_sw/_se set GRUB stretches into a box."""
    size = radius * 2 + 2
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(tile).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=fill,
        outline=edge, width=1 if edge else 0,
    )

    r, inner = radius, size - radius
    parts = {
        "nw": (0, 0, r, r), "ne": (inner, 0, size, r),
        "sw": (0, inner, r, size), "se": (inner, inner, size, size),
        "n": (r, 0, r + 1, r), "s": (r, inner, r + 1, size),
        "w": (0, r, r, r + 1), "e": (inner, r, size, r + 1),
        "c": (r, r, r + 1, r + 1),
    }
    for name, box in parts.items():
        tile.crop(box).save(OUT / f"{prefix}_{name}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "icons").mkdir(exist_ok=True)

    background()
    nine_slice("select", SELECT_RADIUS, SELECT_FILL)

    icon = drive_icon()
    for name in ICON_CLASSES:
        icon.save(OUT / "icons" / f"{name}.png")

    print(f"wrote background.png, select_*.png and icons/ ({', '.join(ICON_CLASSES)}) into {OUT}/")


if __name__ == "__main__":
    main()
