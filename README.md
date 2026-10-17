# zenix

A macOS-flavoured Arch Linux desktop — Hyprland, Quickshell, Neovim — kept in
one repo and installed by one script.

Every surface — editor, terminal, bar, launcher, popups, lock screen, greeter —
is painted from one named theme, switched with `zenix theme set`. Five ship:
the four Catppuccin flavours and `xcode-zenix`, the original Xcode Dark and
macOS Sonoma pairing. The terminal and everything in it is opaque; the bar,
the launcher and the popups stay translucent over the compositor's blur.

Most configs are symlinks back into this checkout, so a change made on the
machine is a change made to the repo — the few that cannot be are generated or
patched instead, and [How installing works](#how-installing-works) says which
and why.

```
./install.sh              # full install
./install.sh --dry-run    # print every step, change nothing
./install.sh --configs-only
```

Arch only. `install.sh` drives `pacman`, `yay` and `systemctl` directly, and
assumes Hyprland on Wayland.

---

## Layout

| | |
|---|---|
| `install.sh` | the whole installer: packages, dotfiles, services, greeter, GRUB |
| `packages/` | `pacman.txt` (216) and `aur.txt` (8), one package per line |
| `hypr/` | `hyprland.lua`, hypridle, hyprlock, hyprpaper |
| `shell/` | zenix-shell — one Quickshell process hosting every popup |
| `bin/zenix-shell` | the IPC wrapper every popup keybind calls |
| `themes/` | one JSON per theme — the source every surface is generated from |
| `nvim/` | LazyVim config and the `zenix` colorscheme |
| `waybar/` | bar config, style, and the module scripts |
| `ghostty/`, `tmux/`, `lazygit/`, `fzf/`, `btop/`, `fastfetch/` | terminal and TUI configs, all on the Xcode palette |
| `wofi/` | the launcher, styled after Spotlight rather than the editor palette |
| `qt6ct/` | dark palette for Qt apps; GTK apps get theirs from `hyprland.lua` |
| `zsh/` | `.zshrc`, plus `tmux-sessioniser.sh` and its config |
| `cli/` | the `zenix` CLI (Python) |
| `sddm/`, `grub/` | greeter and bootloader themes |
| `systemd/` | the agenda fetch timer |
| `webapps/` | `.desktop` entries wrapping sites as apps |
| `assets/wallpaper/` | wallpapers, the source of truth for desktop and greeter |
| `user_configuration.json` | archinstall answers, so a reinstall starts from the same base |

Three directories have their own README with the reasoning behind them:
[`shell/`](shell/README.md), [`cli/`](cli/README.md), [`grub/`](grub/README.md).

---

## Keys

Hyprland, `SUPER` as the modifier.

| | |
|---|---|
| `Return` | terminal (ghostty) |
| `Space` | launcher (wofi, toggles) |
| `Shift`+`E` | file manager |
| `Q` | close window |
| `V` / `F` / `P` / `J` | float · fullscreen · pseudo · toggle split |
| `L` | lock |
| `1`–`0` | workspace, `Shift` to move the window there |
| `Ctrl`+`←` `→` | previous / next **existing** workspace |
| `←` `→` `↑` `↓` | move focus, `Shift` to move the window |
| `A` | scratchpad, `Shift` to move the window there |
| drag / right-drag | move / resize |
| `Print` | screenshot to clipboard, `Shift`+`S` for a region |
| `Shift`+`V` | clipboard history |

Popups, all served by the one Quickshell process:

| | |
|---|---|
| `M` | power — lock, log out, sleep, restart, shut down |
| `S` | sound — output and input devices, volume per device |
| `B` | bluetooth |
| `W` | Wi-Fi |
| `D` | Docker containers |
| `Shift`+`H` | keybindings — every bind on this desktop, grouped |
| click the waybar clock | calendar and today's agenda |
| click the waybar cpu / memory meter | btop, on the matching preset |

`SUPER`+`E` folds every tiled window on the workspace into one tabbed group —
i3's tabbed layout. Tabs appear in a pill along the bottom of the monitor;
`SUPER`+`Tab` cycles them. See [`shell/README.md`](shell/README.md#tabs) for why
the bar is a screen strip rather than a per-tile bar.

In zsh: `Ctrl`+`F` opens the tmux sessionizer, `Ctrl`+`A` attaches a session,
`Ctrl`+`L` lists them, `Ctrl`+`Q` detaches. In tmux the prefix is unchanged;
`prefix`+`f` runs the sessionizer, `prefix`+`|` and `prefix`+`-` split, and
`prefix`+`r` reloads the config.

---

## The theme

One palette, named in `themes/`, applied to every surface at once:

```
zenix theme list                      # the five, current one tagged
zenix theme current                   # and whether every surface agrees
zenix theme set catppuccin-mocha
zenix theme show catppuccin-latte     # the resolved palette, role by role
```

| | |
|---|---|
| `catppuccin-mocha` | the default — darkest flavour, blue accent |
| `catppuccin-macchiato`, `catppuccin-frappe` | the same, one and two steps lighter |
| `catppuccin-latte` | the light flavour |
| `xcode-zenix` | the original: Xcode Dark for the editor, macOS Sonoma for the desktop |

A theme file is the *only* place a colour is written by hand. Everything else
is generated from it, one of four ways depending on how much the target file
carries besides colour: written outright when it is nothing but palette
(`ghostty/themes/`, `btop/themes/`, `qt6ct/colors/`, nvim's palette module,
`shell/Commons/Color.qml`); only the region between `>>> zenix theme <<<`
markers when there is layout worth keeping (both GTK stylesheets, as
`@define-color` declarations the rules then reference; `hyprland.lua`;
`fzfrc`; `tmux/themes.sh`; the greeter's `theme.conf`; the agenda script);
anchored on structure where the app rewrites the file and drops comments
(`lazygit/config.yml`); or a single selector line the app reads for itself
(ghostty, btop, qt6ct, fastfetch, and the `gsettings` calls in
`hyprland.lua`). The roles are the names the repo already used, so nothing was
invented to fit — `themes/xcode-zenix.json` is the old hand-written values
extracted verbatim, and selecting it reproduces them byte for byte. That is
also the test: `zenix theme set xcode-zenix` must leave `git diff` empty.

Generated output is committed, so `install.sh` only ever links it — the
generator is `zenix theme set` and nothing else. Apps that select a theme by
name get a file for *every* theme, so those directories are always complete.

```
background #1e1e2e   keywords #f5c2e7   strings  #f38ba8   numbers  #f9e2af
foreground #cdd6f4   comments #6c7086   preproc  #fab387   selected #45475a
```

Three mappings are judgement calls rather than lookups, and are commented
where they are made. `on_accent` is the one that matters: Sonoma's accent is a
dark blue carrying white text, and every Catppuccin blue is light and cannot —
leave it white and waybar's active workspace pill measures 2.1:1. The
white-alpha overlays become a ladder of eight tinted to each flavour's text
colour; they stay *alpha* rather than taking Catppuccin's opaque surfaces,
because the shell's cards are blurred by the layer rule in `hyprland.lua` and
an opaque fill would throw that away. And a focused window border, which was a
macOS white hairline with no analogue here, becomes a blue-to-sapphire
gradient, with group borders on lavender so a grouped window stays
distinguishable from a merely focused one.

`themes/make-catppuccin.py` is a dev-time tool, not part of the CLI: it maps
the upstream Catppuccin palettes onto these roles and writes the four flavour
files, so changing the accent is one constant rather than 4 × 40 values.
`--check` fails if the committed files have drifted from it.

Two themes need packages: the GTK theme (`catppuccin-gtk-theme-*`, one per
flavour, each shipping all fourteen accents) and the recoloured Papirus
folders. Both are in `packages/aur.txt`. `zenix theme set` warns if the GTK
theme a theme names is not installed, because `GTK_THEME` is read at session
start — an uninstalled name shows up as every GTK3 app falling back to a light
theme at next login rather than as an error now.

`nvim/lua/zenix/` is a colorscheme written for this repo rather than a plugin.
It reproduces the part most ports skip: Xcode colours identifiers in three
tiers by origin — a type you declared, a type from your project, a type from a
framework — which is mapped onto Neovim's LSP semantic tokens, so it behaves
like Xcode rather than merely looking like it. That structure is the palette's,
not Xcode's, so it survives the switch: under Catppuccin the three tiers are
blue, teal and lavender.

The terminal carries the same sixteen ANSI colours, which is what makes the
rest fall into place: `eza` and `fd` colour through those slots, so `fzf`
previews and directory listings match without either tool needing a theme of
its own. The Catppuccin themes use Catppuccin's own slot mapping rather than
Xcode's, because that is what those ports are tuned for.

The editor chrome is Sublime-shaped rather than Xcode-shaped — a flat status
bar, tabs that sit on the editor background, a sidebar with no file icons.

`fastfetch/config.jsonc` reports the desktop rather than just the machine:
alongside os, kernel and hardware it names the compositor, the bar, how many
plugins zenix-shell is hosting, the editor, the multiplexer and the commit the
dotfiles sit on — that last one read by resolving `~/.config/hypr/hyprland.lua`
back to the checkout, so it works wherever the repo lives. Sections are ruled
the way the popups rule theirs, every row carries a Nerd Font icon, and colours
are ANSI indexes rather than hex so the terminal's own palette drives them —
the closing block is that palette, all sixteen slots. `ff` in zsh is the alias.

`btop/themes/<theme>.theme` takes its gradients from the same roles the bar's
meters use — CPU green through amber to red, memory blue — so the meter you
clicked and the box that opens are the same colour. `btop/btop.conf` is linked, not generated: btop rewrites the
whole file when a setting changes in-app, so those edits land in the repo the
way lazygit's do. `presets` there is what `waybar/scripts/btop.sh` selects
between — preset 1 is CPU and processes, preset 2 memory, disks and processes.
The script focuses an existing `zenix.btop` window instead of opening a second
one, so clicking a meter twice does not stack terminals.

---

## How installing works

Three mechanisms, chosen per file for a reason.

**Linked.** Most configs are symlinks into this checkout, so editing the live
file edits the repo. That matters most for the ones an application rewrites by
itself: lazygit rewrites its whole config whenever a setting changes in-app, so
without the link your theme would be clobbered by the next toggle.

**Generated.** `hyprpaper.conf` and `hyprlock.conf` are written, not linked —
neither expands `$HOME`, so the absolute wallpaper path has to be baked in.
`~/.zshenv` likewise, because the repo copy would hardcode one username.

**Patched.** `tmux/themes.sh` is installed over tokyo-night-tmux's own copy.
The plugin ships four hardcoded palettes and offers no hook for a custom one,
and all twelve of its widget scripts source that one file — so owning it is the
only way to recolour the whole bar. A plugin update restores the upstream file,
which is why `install.sh` reapplies it on every run.

`retire()` moves pre-zenix leftovers out of the way. It exists because `link()`
can only back up a file it is about to replace, and some stale configs have no
counterpart here — a stray `~/.config/hypr/hyprland.conf` or a second
`~/.tmux.conf` would otherwise sit there being read.

Everything lands in `~/.dotfiles-backup/<timestamp>/` first. Nothing is deleted.

---

## The `zenix` CLI

For the settings that change often and would otherwise drift between the repo
and the running machine:

```
zenix status                          # what is configured where, repo vs live
zenix wallpaper set NAME [--greeter]
zenix keyboard set LAYOUT [--variant V]
zenix timezone set ZONE
zenix webapp add|remove|list          # sites wrapped as .desktop apps
zenix agenda fetch                    # refresh the calendar cache (the timer calls this)
```

Every command writes the repo first and only then touches the live system,
because the repo is what a rebuild starts from — a change applied live but not
written back is a change lost at the next install. `zenix status` exists to show
when the two have drifted anyway. Details in [`cli/README.md`](cli/README.md).

---

## Rebuilding a machine

`user_configuration.json` holds the archinstall answers, so a fresh disk starts
from the same base — locale, keyboard, filesystem, audio stack. After the first
boot, clone this repo and run `install.sh`.

`packages/refresh.sh` dumps what is actually installed to `pacman.raw.txt` and
`aur.raw.txt` and prints what is new since the curated lists. It deliberately
does not overwrite them: the lists in git have had the repo/AUR split and the
Plasma and font trimming applied by hand, and a raw dump would undo that. Diff,
then take what you want.
