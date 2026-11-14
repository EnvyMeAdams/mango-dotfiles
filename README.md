# mango-dotfiles

My [mango](https://mangowm.github.io) config, on Gentoo with OpenRC (the
ThinkPad). A port of [hyprland-dotfiles](https://github.com/EnvyMeAdams/hyprland-dotfiles):
same keybinds, same split-by-topic layout, same dwindle tiling. The shell on
top is the Quickshell dynamic island from
[quickshell-dotfiles](https://github.com/EnvyMeAdams/quickshell-dotfiles).

```
install.sh                sets everything up (see Install)
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

## Switching the ThinkPad from Hyprland

1. Set up binaries and install the packages: [PACKAGES.md](PACKAGES.md) steps 1-3.
2. Update the island (it has the mango fixes):
   `cd ~/quickshell-dotfiles && git pull`
3. Install this config:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/EnvyMeAdams/mango-dotfiles/main/install.sh | sh
   ```
   It replaces `~/.bash_profile` (old one kept as `.bash_profile.old`), so tty1
   now starts mango instead of Hyprland.
4. Check it parses: `mango -c ~/.config/mango/config.conf -p`
5. Log out, log in on tty1. If something's wrong, switch to tty2 and run
   `dbus-run-session start-hyprland` to get Hyprland back while you fix it
   (until you remove it in step 7).
6. Login screen (if you use it), so greetd runs the login screen in mango:
   ```sh
   doas ~/quickshell-dotfiles/greeter/install.sh --compositor mango --enable
   ```
7. Once everything works: remove Hyprland ([PACKAGES.md](PACKAGES.md) step 5).

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
