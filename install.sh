#!/bin/sh
# Installs these dotfiles for the current user.
#
#   From GitHub:  curl -fsSL https://raw.githubusercontent.com/EnvyMeAdams/mango-dotfiles/main/install.sh | sh
#   From a clone: ~/.config/mango/install.sh
#
#   --no-island   skip the Quickshell island (quickshell-dotfiles)
#
# Safe to run again: anything it would replace is moved to <name>.old first,
# and links that are already right are left alone. Installs no packages;
# it lists what's missing at the end (see PACKAGES.md for the emerge lines).
set -eu

REPO=https://github.com/EnvyMeAdams/mango-dotfiles
ISLAND_REPO=https://github.com/EnvyMeAdams/quickshell-dotfiles
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
MANGO="$CONF/mango"
island=1
for a in "$@"; do
	case "$a" in
	--no-island) island=0 ;;
	*) echo "Unknown option: $a" >&2; exit 2 ;;
	esac
done

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

[ "$(id -u)" -ne 0 ] || { echo "Run this as yourself, not as root." >&2; exit 1; }
command -v git >/dev/null || { echo "git is needed: doas emerge --ask --getbinpkg dev-vcs/git" >&2; exit 1; }

# ── 1. the repo itself, at ~/.config/mango ──
if [ -d "$MANGO/.git" ]; then
	say "Updating $MANGO"
	git -C "$MANGO" pull --ff-only || note "Couldn't fast-forward (local changes?). Leaving it as is."
else
	if [ -e "$MANGO" ]; then
		mv "$MANGO" "$MANGO.old-$(date +%Y%m%d-%H%M%S)"
		note "Moved your existing $MANGO aside"
	fi
	say "Cloning dotfiles into $MANGO"
	git clone "$REPO" "$MANGO"
fi

# ── 2. links ──
# link <file in repo> <where it goes>
link() {
	src="$MANGO/$1" dst="$2"
	mkdir -p "$(dirname "$dst")"
	if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
		note "ok   ${dst#"$HOME"/}"
		return
	fi
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		mv "$dst" "$dst.old"
		note "kept your old ${dst#"$HOME"/} as ${dst#"$HOME"/}.old"
	fi
	ln -s "$src" "$dst"
	note "link ${dst#"$HOME"/}"
}
say "Linking config files"
link kitty/kitty.conf          "$CONF/kitty/kitty.conf"
link fastfetch/config.jsonc    "$CONF/fastfetch/config.jsonc"
link gtk/thunar-glass.css      "$CONF/gtk-3.0/thunar-glass.css"
link portals/mango-portals.conf "$CONF/xdg-desktop-portal/mango-portals.conf"
link shell/bashrc              "$HOME/.bashrc"
link shell/bash_profile        "$HOME/.bash_profile"
# screen-share picker config: the portal doesn't expand ~, so write it with the real path
xdpw="$CONF/xdg-desktop-portal-wlr/config"
mkdir -p "$(dirname "$xdpw")"
[ -L "$xdpw" ] && rm -f "$xdpw"
if [ -f "$xdpw" ] && ! grep -q 'share-picker' "$xdpw"; then
	mv "$xdpw" "$xdpw.old"
	note "kept your old ${xdpw#"$HOME"/} as ${xdpw#"$HOME"/}.old"
fi
sed "s|@HOME@|$HOME|" "$MANGO/portals/xdpw.conf" > "$xdpw"
note "wrote ${xdpw#"$HOME"/} (click a window or a display to share)"
mkdir -p "$CONF/fastfetch/logos" "$HOME/Pictures/Screenshots" "$HOME/Videos/Recordings"
chmod +x "$MANGO/scripts/"* 2>/dev/null || true
[ -f "$MANGO/local.conf" ] || printf '# This machine only (not in the repo). Loaded last.\n' > "$MANGO/local.conf"

# ── 3. Thunar: liquid glass (gtk/thunar-glass.css, Thunar only) ──
gtkcss="$CONF/gtk-3.0/gtk.css"
if ! grep -qs 'thunar-glass.css' "$gtkcss"; then
	{ printf '@import url("thunar-glass.css");\n'; cat "$gtkcss" 2>/dev/null || true; } > "$gtkcss.new"
	mv "$gtkcss.new" "$gtkcss"
	note "Thunar glass theme added to ${gtkcss#"$HOME"/}"
fi
# folders open in Thunar ("show in folder", downloads, the island)
if command -v xdg-mime >/dev/null && command -v thunar >/dev/null; then
	xdg-mime default thunar.desktop inode/directory && note "Thunar is the default for folders"
fi

# ── 4. the Quickshell island ──
if [ "$island" = 1 ]; then
	dir="$HOME/quickshell-dotfiles"
	if [ -d "$dir/.git" ]; then
		say "Updating the island ($dir)"
		git -C "$dir" pull --ff-only || note "Couldn't fast-forward the island repo. Leaving it."
	else
		say "Cloning the island into $dir"
		git clone "$ISLAND_REPO" "$dir"
	fi
	sh "$dir/install.sh" | sed 's/^/    /'
fi

# ── 5. colours from the wallpaper, once now (the login autostart keeps them current) ──
if python3 -c "import PIL" 2>/dev/null; then
	"$MANGO/scripts/wallpaper-colors" 2>/dev/null || note "No island wallpaper set yet; colours follow once you pick one"
fi

# ── 6. check the config parses ──
if command -v mango >/dev/null; then
	if mango -c "$MANGO/config.conf" -p >/dev/null 2>&1; then note "mango config: ok"
	else note "mango config has errors: run  mango -c $MANGO/config.conf -p"; fi
fi

# ── 7. what's missing ──
say "Checking programs"
missing=""
need() {   # need <command> <package>
	command -v "$1" >/dev/null 2>&1 || missing="$missing $2"
}
need mango gui-wm/mangowm
need quickshell gui-apps/quickshell
need kitty x11-terms/kitty
need thunar xfce-base/thunar
need fastfetch app-misc/fastfetch
command -v firefox >/dev/null || command -v firefox-bin >/dev/null || missing="$missing www-client/firefox"
need wpctl media-video/wireplumber
need playerctl media-sound/playerctl
need brightnessctl app-misc/brightnessctl
need grim gui-apps/grim
need slurp gui-apps/slurp
need wl-copy gui-apps/wl-clipboard
need wf-recorder gui-apps/wf-recorder
need wlsunset gui-apps/wlsunset
need wlr-randr gui-apps/wlr-randr
need ffmpegthumbnailer media-video/ffmpegthumbnailer
need gnome-keyring-daemon gnome-base/gnome-keyring
[ -x /usr/libexec/xdg-desktop-portal ] || missing="$missing sys-apps/xdg-desktop-portal"
[ -x /usr/libexec/xdg-desktop-portal-wlr ] || missing="$missing gui-libs/xdg-desktop-portal-wlr"
[ -x /usr/libexec/xdg-desktop-portal-gtk ] || missing="$missing sys-apps/xdg-desktop-portal-gtk"
[ -x /usr/libexec/polkit-gnome-authentication-agent-1 ] || missing="$missing gnome-extra/polkit-gnome"
python3 -c "import PIL" 2>/dev/null || missing="$missing dev-python/pillow"
if [ -n "$missing" ]; then
	note "Not installed:$missing"
	note "Install with: doas emerge --ask --getbinpkg$missing"
	note "(mangowm and quickshell need the guru repo + ~amd64; see PACKAGES.md)"
else
	note "Everything's installed"
fi

echo
say "Done. Next:"
note "Put fastfetch pictures in ~/.config/fastfetch/logos/"
note "Check config/monitors.conf matches this machine's screens (wlr-randr lists them)"
[ "$island" = 1 ] && note "Login screen (optional): doas ~/quickshell-dotfiles/greeter/install.sh --compositor mango --enable"
note "Log out and back in (or reboot) to start mango"
