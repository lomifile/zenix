#!/usr/bin/env bash
#
# Regenerate the theme's images and fonts into theme/.
#
# The output is committed, so install.sh only has to copy it — a fresh machine
# does not need imagemagick or a font toolchain. Re-run this only when changing
# the design. Needs: python-pillow, grub (for grub-mkfont), inter-font.

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

OUT=theme
INTER=/usr/share/fonts/inter/InterVariable.ttf

command -v grub-mkfont >/dev/null || { echo "grub-mkfont missing (pacman -S grub)" >&2; exit 1; }
python3 -c 'import PIL' 2>/dev/null || { echo "python-pillow missing" >&2; exit 1; }
[[ -f "$INTER" ]] || { echo "$INTER missing (pacman -S inter-font)" >&2; exit 1; }

mkdir -p "$OUT"

echo "==> fonts"
# GRUB has no font fallback and cannot scale: every size used in theme.txt has
# to be baked into its own .pf2. -n sets only the FAMILY; grub-mkfont appends
# the style and size itself, so the name theme.txt must match ends up as
# "Inter Regular <size>".
grub-mkfont -s 16 -n "Inter" -o "$OUT/inter-16.pf2" "$INTER"
grub-mkfont -s 20 -n "Inter" -o "$OUT/inter-20.pf2" "$INTER"
grub-mkfont -s 13 -n "Inter" -o "$OUT/inter-13.pf2" "$INTER"

echo "==> images"
python3 mkassets.py "$OUT"

echo
echo "theme/ regenerated:"
ls -la "$OUT"
