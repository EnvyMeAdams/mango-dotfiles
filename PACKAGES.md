# Packages (Gentoo, OpenRC, binaries first)

The ThinkPad pulls everything it can from Gentoo's official binhost and only
compiles what the binhost doesn't carry. Checked against the binhost
(`23.0/x86-64`) in November 2026.

## 1. Turn on binaries

`/etc/portage/binrepos.conf/gentoobinhost.conf`:

```ini
[gentoobinhost]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/
```

`/etc/portage/make.conf` (add to what's there):

```sh
FEATURES="${FEATURES} getbinpkg binpkg-request-signature"
```

Then fetch the signing keys once:

```sh
doas getuto
```

Two things decide whether you get a binary or a compile:

- **USE flags.** A binary is only used when its USE flags match yours. Every
  flag you change from the profile's defaults makes that package compile. Use
  the `desktop` profile (`default/linux/amd64/23.0/desktop`, OpenRC) and keep
  `package.use` short: only what a program below actually needs.
- **Keywords.** The binhost only builds stable (`amd64`) packages. Never set
  `ACCEPT_KEYWORDS="~amd64"` globally; keyword single packages instead (step 2).

`CFLAGS`/`-march` don't matter: binaries are built for generic x86-64 and run
fine on the T440p.

To see which packages would compile before you commit, look for `[ebuild` (compile)
versus `[binary` in:

```sh
doas emerge -pv --getbinpkg <packages>
```

## 2. GURU (for mango, quickshell)

```sh
doas emerge --ask --getbinpkg app-eselect/eselect-repository
doas eselect repository enable guru
doas emerge --sync guru
```

`/etc/portage/package.accept_keywords/mango`:

```
gui-wm/mangowm ~amd64
gui-libs/scenefx ~amd64
gui-apps/quickshell ~amd64
```

`/etc/portage/package.use/mango` (mango builds without XWayland unless you ask;
Hyprland had it, and X11/Electron apps need it):

```
gui-wm/mangowm X
```

## 3. Install

Everything at once:

```sh
doas emerge --ask --getbinpkg \
  gui-wm/mangowm gui-apps/quickshell \
  gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard gui-apps/wf-recorder \
  gui-apps/wlsunset gui-apps/wlr-randr \
  sys-apps/xdg-desktop-portal sys-apps/xdg-desktop-portal-gtk gui-libs/xdg-desktop-portal-wlr \
  gnome-extra/polkit-gnome gnome-base/gnome-keyring \
  media-video/pipewire media-video/wireplumber media-sound/playerctl app-misc/brightnessctl \
  media-video/ffmpegthumbnailer media-sound/cava dev-python/pillow \
  x11-terms/kitty app-misc/fastfetch sys-apps/fd \
  xfce-base/thunar gnome-base/gvfs xfce-base/tumbler
```

What that does:

| Comes as a binary | Compiles (not on the binhost) |
|---|---|
| wlroots 0.20 (mango's base), Qt 6 (qtbase, qtdeclarative, qtmultimedia, qtsvg…), PipeWire, WirePlumber, ffmpeg, mpv | **mangowm**, **scenefx** (GURU) |
| xdg-desktop-portal, xdg-desktop-portal-gtk | **quickshell** (GURU) |
| polkit-gnome (replaces hyprpolkitagent) | dev-qt/qtwayland (quickshell needs it) |
| gnome-keyring, wl-clipboard | grim, slurp, wf-recorder, wlsunset, wlr-randr |
| GTK, libadwaita, dbus, ripgrep, Thunar, gvfs, tumbler | xdg-desktop-portal-wlr |
| | kitty, fastfetch, playerctl, brightnessctl, cava, ffmpegthumbnailer, fd |

The compile column is all small programs except qtwayland and quickshell.
mango itself builds in about a minute. Firefox is left as your own PGO build;
`www-client/firefox-bin` is the binary option if you ever want to skip it.

## 4. Move what's already installed to binaries

Reinstalls everything, taking the binary wherever one matches your USE flags
and compiling the rest. Firefox is left out so your PGO build isn't redone:

```sh
doas emerge --ask --getbinpkg --emptytree --exclude www-client/firefox @world
```

Before running it, `-p` shows the split. If a big package still says
`[ebuild` (compile), a USE flag you changed is the reason: `emerge -pv` shows
which, and putting it back to the profile default gets you the binary. For the
kernel, `sys-kernel/gentoo-kernel-bin` is the binary one.

## 5. Remove Hyprland (after mango works)

```sh
doas emerge --ask --deselect gui-wm/hyprland gui-apps/hyprshot gui-apps/hyprpolkitagent \
  gui-libs/xdg-desktop-portal-hyprland gui-apps/hyprsunset
doas emerge --ask --depclean
```

`--depclean` takes the Hypr libraries with it (aquamarine, hyprutils, hyprlang,
hyprcursor, hyprgraphics, hyprland-qt-support…). Check its list before saying
yes. If you had HyprMod installed outside Portage, remove it the same way you
installed it.

## Swaps

| Hyprland | mango | Why |
|---|---|---|
| hyprshot | grim + slurp (island's script) | hyprshot needs hyprctl |
| hyprsunset | wlsunset | hyprsunset is Hyprland-only |
| hyprpolkitagent | polkit-gnome | binary on the binhost, works anywhere |
| xdg-desktop-portal-hyprland | xdg-desktop-portal-wlr | screen sharing on wlroots compositors |
| hyprctl | mmsg | mango's IPC tool (comes with mango) |
| Hyprcursor theme | XCursor theme (`cursor_theme=`) | mango reads XCursor only |
