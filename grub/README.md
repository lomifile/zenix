# zenix GRUB theme

Modelled on the macOS Startup Manager: a flat near-black ground, one large
silver disk icon per entry, generous negative space, and a selection that is a
soft fill rather than a button. No title, no keyboard hints, no colour -- those
read as a Linux theme rather than a Mac one.

```
grub/
├── build.sh      regenerates theme/ (fonts + images)
├── mkassets.py   background and the selection nine-slice
├── preview.py    renders an approximation of the boot screen to a PNG
└── theme/        the theme itself, copied to /boot/grub/themes/zenix
    └── icons/    per-entry icons, keyed by the --class grub-mkconfig emits
```

`theme/` is committed, so `install.sh` only copies it — a fresh machine needs
no imaging or font toolchain. Rebuilding it needs `python-pillow`, `inter-font`
and `grub` (for `grub-mkfont`); none of those are required to *install*.

## Two things GRUB is fussy about

**Font names.** GRUB has no font fallback and cannot scale, so every size in
`theme.txt` is a separate `.pf2`, matched by the name baked inside it.
`grub-mkfont -n` sets only the *family* — it appends the style and size itself,
so `-n "Inter"` at size 20 yields `Inter Regular 20`, which is what `theme.txt`
must say. Get this wrong and GRUB silently falls back to its built-in font.

**Entry icons are looked up by class.** grub-mkconfig tags Linux entries
`--class gnu-linux --class gnu --class os`, so `icons/` carries a file per
name. The UEFI firmware entry is emitted with no class at all, so it gets no
icon and its slot stays empty -- that is grub, not a missing file.

**The menu has to be shown.** `GRUB_TIMEOUT_STYLE=hidden` boots straight
through and never draws the theme; `install.sh` sets it to `menu`. A
`GRUB_TERMINAL_OUTPUT=console` line also disables it, since themes require
gfxterm — the installer warns if it finds one.

## Iterating

```sh
./build.sh          # after editing mkassets.py
./preview.py out.png
```

`preview.py` mirrors `theme.txt`'s geometry by hand rather than parsing it, so
keep the two in step when moving things around.
