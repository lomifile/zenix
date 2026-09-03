# zenix

A macOS-flavoured Arch Linux desktop — Hyprland, Quickshell, Neovim — kept in
one repo and installed by one script.

The editor, terminal, status bars, picker and git UI all share one palette
(Xcode Dark); the compositor's own surfaces follow macOS Sonoma. Most configs
are symlinks back into this checkout, so a change made on the machine is a
change made to the repo — the few that cannot be are generated or patched
instead, and [How installing works](#how-installing-works) says which and why.

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
| `nvim/` | LazyVim config and the `xcode-zenix` colorscheme |
| `waybar/` | bar config, style, and the module scripts |
| `ghostty/`, `tmux/`, `lazygit/`, `fzf/` | terminal and TUI configs, all on the Xcode palette |
| `wofi/` | the launcher, styled after Spotlight rather than the editor palette |
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
| click the waybar clock | calendar and today's agenda |

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

One palette, Xcode Dark, applied everywhere:

```
background #292a30   keywords #ff7ab2   strings  #ff8170   numbers  #d9c97c
foreground #dfdfe0   comments #7f8c98   preproc  #ffa14f   selected #414453
```

`nvim/lua/xcode-zenix/` is a colorscheme written for this repo rather than a
plugin. It reproduces the part most ports skip: Xcode colours identifiers in
three tiers by origin — a type you declared, a type from your project, a type
from a framework — which is mapped onto Neovim's LSP semantic tokens, so it
behaves like Xcode rather than merely looking like it.

The terminal carries the same sixteen ANSI colours, which is what makes the rest
fall into place: `eza` and `fd` colour through those slots, so `fzf` previews and
directory listings match without either tool needing a theme of its own.

The editor chrome is Sublime-shaped rather than Xcode-shaped — a flat status
bar, tabs that sit on the editor background, a sidebar with no file icons — on
the Xcode palette.

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
