#!/usr/bin/env python3
"""Generate the theme's PNGs.

Sonoma palette, same values the rest of the setup uses:
    background   #0e0e10 -> #1c1c1e, with a soft bloom
    selection    white 12% fill, white 20% hairline
    accent       #0a84ff (systemBlue dark)
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "theme")
W, H = 1920, 1080

SELECT_RADIUS = 12          # rounded rect, as macOS menu rows use;
                            # must stay well under item_height/2 so the
                            # nine-slice keeps a non-zero middle strip
SELECT_FILL = (255, 255, 255, 31)     # ~12%
SELECT_EDGE = (255, 255, 255, 51)     # ~20%


def background() -> None:
    """Vertical charcoal gradient with an off-centre bloom and a vignette."""
    base = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(base)
    top, bottom = (0x14, 0x14, 0x16), (0x0A, 0x0A, 0x0C)
    for y in range(H):
        t = y / (H - 1)
        draw.line(
            [(0, y), (W, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)),
        )

    # Sonoma's wallpapers all carry a soft coloured bloom; this is a cheap
    # stand-in that survives GRUB's crop scaling at any aspect ratio.
    bloom = Image.new("RGB", (W, H), (0, 0, 0))
    bd = ImageDraw.Draw(bloom)
    bd.ellipse([W * 0.18, -H * 0.55, W * 0.82, H * 0.62], fill=(0x14, 0x2A, 0x4A))
    bd.ellipse([W * 0.30, -H * 0.40, W * 0.70, H * 0.42], fill=(0x1E, 0x3C, 0x66))
    bloom = bloom.filter(ImageFilter.GaussianBlur(190))
    base = Image.blend(base, Image.blend(base, bloom, 0.85), 0.55)

    # vignette
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([-W * 0.15, -H * 0.35, W * 1.15, H * 1.35], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(220))
    base = Image.composite(base, Image.new("RGB", (W, H), (5, 5, 6)), mask)

    base.save(OUT / "background.png")


def nine_slice(prefix: str, radius: int, fill, edge) -> None:
    """Emit the *_c/_n/_s/_e/_w/_nw/_ne/_sw/_se set GRUB stretches into a box."""
    size = radius * 2 + 2
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(tile).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=fill, outline=edge, width=1
    )

    r = radius
    inner = size - r          # first pixel past the corner
    parts = {
        "nw": tile.crop((0, 0, r, r)),
        "ne": tile.crop((inner, 0, size, r)),
        "sw": tile.crop((0, inner, r, size)),
        "se": tile.crop((inner, inner, size, size)),
        "n": tile.crop((r, 0, r + 1, r)),
        "s": tile.crop((r, inner, r + 1, size)),
        "w": tile.crop((0, r, r, r + 1)),
        "e": tile.crop((inner, r, size, r + 1)),
        "c": tile.crop((r, r, r + 1, r + 1)),
    }
    for name, img in parts.items():
        img.save(OUT / f"{prefix}_{name}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    background()
    nine_slice("select", SELECT_RADIUS, SELECT_FILL, SELECT_EDGE)
    print(f"wrote background.png and select_*.png into {OUT}/")


if __name__ == "__main__":
    main()
