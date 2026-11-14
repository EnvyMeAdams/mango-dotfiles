# mango-dotfiles

My [mango](https://mangowm.github.io) config, on Gentoo with OpenRC (the
ThinkPad). A port of [hyprland-dotfiles](https://github.com/EnvyMeAdams/hyprland-dotfiles):
same keybinds, same split-by-topic layout, same dwindle tiling. The shell on
top is the Quickshell dynamic island from
[quickshell-dotfiles](https://github.com/EnvyMeAdams/quickshell-dotfiles).

```
setup.sh                  one-line installer: packages, binaries, dotfiles, island, cleanup
install.sh                links the dotfiles only (setup.sh runs it)
config.conf               entry point, sources config/ in order
config/                   one file per topic (monitors, keybinds, autostart…)
local.conf                this machine only, never committed (made by install.sh)
portals/                  which portal does what + the screen-share picker
scripts/
  portals                 starts the desktop portals without systemd
  opencloud               starts the OpenCloud AppImage if it's there
  wallpaper-colors        terminal colours from the current wallpaper
kitty/ fastfetch/ superfile/ shell/   same as in hyprland-dotfiles
PACKAGES.md               what to emerge, binaries first
```

## Install (one line)

From a terminal on the laptop, as yourself (it asks for doas when needed):

```sh
curl -fsSL https://raw.githubusercontent.com/EnvyMeAdams/mango-dotfiles/main/setup.sh | sh
```

It turns on Gentoo's binary packages, enables GURU, installs mango and every
program the config and island use (binaries where the binhost has them), and
installs these dotfiles plus the island. Safe to run again to update.

Options go after `sh -s --`, for example `| sh -s -- --greeter --enable`:

| Option | Does |
|---|---|
| `--greeter` | also install the island login screen, running in mango |
| `--enable` | with `--greeter`: start the login screen at boot |
| `--binaries` | also reinstall what's already installed from binaries where one matches (Firefox left alone) |
| `--cleanup` | remove Hyprland: its packages, your Hyprland dotfiles, the login screen's Hyprland mode |
| `--yes` | don't stop at each emerge to ask |

Then log out and log in on tty1: mango starts there. Hyprland stays installed
until you clean it up, so from tty2 `dbus-run-session start-hyprland` still works.

## Removing Hyprland

Once mango works, run this **from a terminal inside mango** (it refuses otherwise):

```sh
curl -fsSL https://raw.githubusercontent.com/EnvyMeAdams/mango-dotfiles/main/setup.sh | sh -s -- --cleanup
```

- packs `~/.config/hypr` (and Hyprland's caches) into `~/hyprland-backup-<date>.tar.gz`, then deletes them
- removes links that pointed into `~/.config/hypr` (like the Ghostty config)
- switches the login screen from Hyprland to mango if it was on Hyprland
- takes every Hypr package off the world list (hyprland, hyprshot, hyprpolkitagent,
  xdg-desktop-portal-hyprland, hyprlang, aquamarine…), then `emerge --depclean`
  shows everything it will remove, including what only Hyprland needed. Read it before saying yes.

The `hyprland-dotfiles` repo on GitHub isn't touched; the desktop still uses it.

## What maps to what

| Hyprland | mango |
|---|---|
| workspaces 1-10 | tags 1-10 (each display has its own set) |
| dwindle, `preserve_split` | `layout_name:dwindle`, `dwindle_preserve_split=1` |
| `togglesplit` (Super+J) | `dwindle_toggle_current_split` |
| fullscreen maximized / full (Super+F / Shift+F) | `togglemaximizescreen` / `togglefullscreen` |
| Super+scroll `e+1`/`e-1` | `viewtoright_have_client` / `viewtoleft_have_client` |
| 3-finger workspace swipe | `gesturebind` + `gesture_live=1` |
| `locked = true` binds | `bindl` |
| `hyprctl reload` | `reload_config` (also reloads on save) |
| `hl.on("hyprland.start")` | `exec_once=` |
| `hl.env()` | `env=` |
| `suppress_event = "maximize"` | `window_rule=ignore_maximize:1` |
| hyprshot window/output/region | island screenshot script (click a window / this display / drag a box) |

Not carried over: pseudotile (Super+P, nothing like it in mango) and the
gradient border (mango borders are one colour, so it's the pink end).

## Screen sharing

`scripts/portals` starts xdg-desktop-portal-wlr. When an app asks to share,
click the display you want (slurp). Firefox, OBS and Chromium apps work this
way. Sharing a single window doesn't work in every app (mango's docs list it as
a known issue); share the whole display if it fails.

## Terminal colours

Same as in hyprland-dotfiles: `scripts/wallpaper-colors --watch` runs at login
and themes kitty, superfile and fastfetch from the island's wallpaper.
Needs `dev-python/pillow`, and `ffmpegthumbnailer` for video wallpapers.
