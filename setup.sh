#!/bin/sh
# One-line setup for mango on Gentoo (OpenRC), binaries first:
#
#   curl -fsSL https://raw.githubusercontent.com/EnvyMeAdams/mango-dotfiles/main/setup.sh | sh
#
# Does everything in PACKAGES.md and README.md:
#   1. turns on Gentoo's official binary packages (binhost)
#   2. enables GURU and keywords mango, scenefx, quickshell
#   3. installs every program the config and the island use
#   4. installs these dotfiles to ~/.config/mango and the island
#
# Options (put them after "sh -s --"):
#   --greeter      also install the island login screen, running in mango
#   --enable       with --greeter: start the login screen at boot
#   --binaries     also reinstall everything already on the system from
#                  binaries where one matches (Firefox left alone)
#   --cleanup      after mango works: remove Hyprland, its packages and your
#                  Hyprland dotfiles from this machine (run it from mango)
#   --yes          don't ask before each emerge (still asks for doas)
#
# Safe to run again: done steps are skipped, packages already installed
# aren't reinstalled, and anything replaced is kept as <name>.old.

# everything lives in main() so a half-downloaded script never runs
main() {
    set -eu

    REPO=https://github.com/EnvyMeAdams/mango-dotfiles.git
    ISLAND_SETUP=https://raw.githubusercontent.com/EnvyMeAdams/quickshell-dotfiles/main/setup.sh
    CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
    MANGO="$CONF/mango"
    BINHOST=https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/
    greeter=0; enable=0; binaries=0; cleanup=0; ask=--ask

    while [ $# -gt 0 ]; do
        case "$1" in
            --greeter) greeter=1 ;;
            --enable) enable=1 ;;
            --binaries) binaries=1 ;;
            --cleanup) cleanup=1 ;;
            --yes) ask="" ;;
            -h|--help) sed -n '2,24p' "$0" 2>/dev/null || echo "Options: --greeter --enable --binaries --cleanup --yes"; return 0 ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
        shift
    done

    say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
    note() { printf '    %s\n' "$*"; }
    warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
    die()  { printf '\033[1;31m  x\033[0m %s\n' "$*" >&2; exit 1; }
    have() { command -v "$1" >/dev/null 2>&1; }

    [ "$(id -u)" -ne 0 ] || die "Run this as yourself, not root. It asks for doas when it needs it."
    [ -f /etc/gentoo-release ] || die "This is for Gentoo."
    have doas || die "doas isn't installed (app-admin/doas)."
    (: < /dev/tty) 2>/dev/null || die "Needs a terminal (it asks questions). Run it from a terminal window or tty."

    # root commands get the terminal, because stdin is this script when piped from curl
    root() { doas "$@" < /dev/tty; }
    # root_write <file>: write stdin to a root-owned file
    root_write() { doas sh -c 'mkdir -p "$(dirname "$1")" && cat > "$1"' sh "$1"; }
    emerge_() { root emerge $ask --getbinpkg "$@"; }

    # portage_add <package.use|package.accept_keywords> <lines...>
    # /etc/portage/<kind> can be a folder or a single file; handle both
    portage_add() {
        kind=$1; shift
        p="/etc/portage/$kind"
        if [ -f "$p" ]; then
            for l in "$@"; do
                grep -qxF "$l" "$p" || printf '%s\n' "$l" | doas sh -c 'cat >> "$1"' sh "$p"
            done
        else
            printf '%s\n' "# added by mango-dotfiles setup.sh" "$@" | root_write "$p/mango"
        fi
        note "$kind: $*"
    }

    if [ "$cleanup" -eq 1 ]; then
        cleanup_hyprland
        return 0
    fi

    # ── 1. binary packages ──
    say "Binary packages (Gentoo binhost)"
    if [ -d /etc/portage/binrepos.conf ] && grep -rqs "binpackages" /etc/portage/binrepos.conf; then
        note "binhost already set up"
    elif [ -f /etc/portage/binrepos.conf ] && grep -qs "binpackages" /etc/portage/binrepos.conf; then
        note "binhost already set up"
    else
        printf '[gentoobinhost]\npriority = 9999\nsync-uri = %s\n' "$BINHOST" |
            root_write /etc/portage/binrepos.conf/gentoobinhost.conf
        note "added $BINHOST"
    fi
    if grep -qs '^[^#]*FEATURES=.*getbinpkg' /etc/portage/make.conf; then
        note "make.conf already has getbinpkg"
    else
        # shellcheck disable=SC2016
        printf '\n# added by mango-dotfiles setup.sh: use binary packages when they match\nFEATURES="${FEATURES} getbinpkg binpkg-request-signature"\n' |
            doas sh -c 'cat >> /etc/portage/make.conf'
        note "make.conf: FEATURES += getbinpkg binpkg-request-signature"
    fi
    # shellcheck disable=SC2015
    if have getuto; then root getuto >/dev/null 2>&1 && note "binhost signing keys ready" || warn "getuto failed; signed binaries may be refused"; fi
    case "$(readlink /etc/portage/make.profile 2>/dev/null)" in
        *systemd*) warn "Your profile is a systemd one; the binaries are built for both, but this setup expects OpenRC." ;;
        */desktop*) ;;
        *) warn "Your profile isn't a desktop one. Many binaries won't match its USE flags and will compile."
           note "Check with: eselect profile list   (OpenRC desktop: default/linux/amd64/23.0/desktop)" ;;
    esac

    # ── 2. GURU + keywords + USE ──
    say "GURU (mango and quickshell live there)"
    # shellcheck disable=SC2015
    have eselect && eselect repository list >/dev/null 2>&1 || emerge_ --noreplace app-eselect/eselect-repository
    if eselect repository list -i 2>/dev/null | grep -qw guru; then
        note "guru already enabled"
    else
        root eselect repository enable guru
    fi
    root emaint sync -r guru >/dev/null && note "guru synced"
    portage_add package.accept_keywords \
        "gui-wm/mangowm ~amd64" "gui-libs/scenefx ~amd64" "gui-apps/quickshell ~amd64"
    # X: XWayland for X11/Electron apps. quickshell -hyprland: mango never uses it
    portage_add package.use "gui-wm/mangowm X" "gui-apps/quickshell -hyprland"

    # ── 3. programs ──
    say "Installing programs (binaries where the binhost has them)"
    note "Lines marked [binary] download, [ebuild] compile."
    # --newuse: rebuilds quickshell if it was built with Hyprland support
    emerge_ --noreplace --newuse \
        gui-wm/mangowm gui-apps/quickshell \
        gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard gui-apps/wf-recorder \
        gui-apps/wlsunset gui-apps/wlr-randr \
        sys-apps/xdg-desktop-portal sys-apps/xdg-desktop-portal-gtk gui-libs/xdg-desktop-portal-wlr \
        gnome-extra/polkit-gnome gnome-base/gnome-keyring \
        media-video/pipewire media-video/wireplumber media-sound/playerctl app-misc/brightnessctl \
        media-video/ffmpegthumbnailer media-sound/cava dev-python/pillow \
        net-misc/networkmanager x11-terms/kitty app-misc/fastfetch sys-apps/fd \
        xfce-base/thunar gnome-base/gvfs xfce-base/tumbler \
        dev-vcs/git net-misc/curl

    if [ "$binaries" -eq 1 ]; then
        say "Reinstalling everything else from binaries where possible"
        note "Packages whose USE flags differ from the binhost still compile (emerge shows which)."
        emerge_ --emptytree --exclude www-client/firefox @world
    fi

    # ── 4. dotfiles + island ──
    say "Dotfiles"
    if [ -d "$MANGO/.git" ]; then
        git -C "$MANGO" pull --ff-only --quiet || warn "Couldn't update $MANGO (local changes?). Using what's there."
    else
        [ -e "$MANGO" ] && { mv "$MANGO" "$MANGO.old-$(date +%Y%m%d-%H%M%S)"; note "moved your old $MANGO aside"; }
        git clone --quiet "$REPO" "$MANGO"
    fi
    # links, local.conf, wallpaper colours, config check (no island: done next)
    sh "$MANGO/install.sh" --no-island | sed -n '/Done. Next/q;p'

    say "The island"
    set --
    [ "$greeter" -eq 1 ] && set -- "$@" --greeter --mango
    [ "$enable" -eq 1 ] && set -- "$@" --enable
    curl -fsSL "$ISLAND_SETUP" | sh -s -- --no-start "$@" | sed "/^.*==> Done/,\$d"

    echo
    say "Done."
    note "Log out, then log in on tty1: mango starts there now (Hyprland is still installed as a fallback:"
    note "  from tty2 run  dbus-run-session start-hyprland)."
    note "Screens: edit ~/.config/mango/config/monitors.conf if they need it (wlr-randr lists them)."
    note "Once mango works, remove Hyprland from inside mango with:"
    note "  curl -fsSL https://raw.githubusercontent.com/EnvyMeAdams/mango-dotfiles/main/setup.sh | sh -s -- --cleanup"
}

# ── --cleanup: Hyprland off this machine ──
cleanup_hyprland() {
    say "Removing Hyprland from this machine"
    if [ -z "${MANGO_INSTANCE_SIGNATURE:-}" ]; then
        die "Run --cleanup from a terminal inside mango, so you know mango works before Hyprland goes."
    fi

    # 1. dotfiles: one backup, then gone
    stamp=$(date +%Y%m%d-%H%M%S)
    backup="$HOME/hyprland-backup-$stamp.tar.gz"
    set --
    for p in "$CONF/hypr" "$CONF/hyprland-gui" "$CONF/hyprmod" "$CONF/xdg-desktop-portal-hyprland" \
             "$HOME/.local/share/hyprland" "$HOME/.local/state/hyprland" "$HOME/.cache/hyprland"; do
        [ -e "$p" ] && set -- "$@" "${p#"$HOME"/}"
    done
    if [ $# -gt 0 ]; then
        tar -czf "$backup" -C "$HOME" "$@" 2>/dev/null && note "backup: ${backup#"$HOME"/} (delete it whenever you like)"
        for p in "$@"; do rm -rf "${HOME:?}/$p"; note "removed ~/$p"; done
    else
        note "no Hyprland config folders left"
    fi
    # links that pointed into ~/.config/hypr (Ghostty config etc.)
    for l in "$HOME/.bashrc" "$HOME/.bash_profile" $(find "$CONF" -maxdepth 3 -type l 2>/dev/null); do
        [ -L "$l" ] || continue
        case "$(readlink "$l")" in
            */.config/hypr/*) rm -f "$l"; rmdir "$(dirname "$l")" 2>/dev/null || true
                              note "removed link ${l#"$HOME"/}" ;;
        esac
    done
    # ~/.bash_profile / ~/.bashrc must still exist (mango starts from bash_profile)
    [ -e "$HOME/.bash_profile" ] || ln -s "$MANGO/shell/bash_profile" "$HOME/.bash_profile"
    [ -e "$HOME/.bashrc" ] || ln -s "$MANGO/shell/bashrc" "$HOME/.bashrc"

    # 2. login screen: make sure greetd no longer starts Hyprland
    # greetd's real config (/etc/greetd/config.toml) is only rewritten with
    # --enable, so pass it whenever that file still starts Hyprland
    if grep -qs -i "hyprland" /etc/greetd/config.toml; then
        say "Switching the login screen to mango"
        root sh "$HOME/quickshell-dotfiles/greeter/install.sh" --compositor mango --enable ||
            warn "Couldn't switch it; run later: doas ~/quickshell-dotfiles/greeter/install.sh --compositor mango --enable"
    fi

    # 3. packages: every installed Hypr* package, then whatever only they needed
    say "Hyprland packages"
    pkgs=""
    for d in /var/db/pkg/*/hypr* /var/db/pkg/*/aquamarine-* /var/db/pkg/*/xdg-desktop-portal-hyprland-*; do
        [ -d "$d" ] || continue
        cat=$(basename "$(dirname "$d")")
        pn=$(basename "$d" | sed -E 's/-[0-9][^-]*(-r[0-9]+)?$//')
        case " $pkgs " in *" $cat/$pn "*) ;; *) pkgs="$pkgs $cat/$pn" ;; esac
    done
    if [ -n "$pkgs" ]; then
        note "found:$pkgs"
        # shellcheck disable=SC2086
        root emerge --deselect $pkgs >/dev/null
        # your own sets (/etc/portage/sets/*) would pull them straight back in
        for f in /etc/portage/sets/*; do
            if [ ! -f "$f" ] || ! grep -qiE '^[^#]*/(hypr|aquamarine|xdg-desktop-portal-hyprland)' "$f"; then continue; fi
            doas sed -i.bak -E '/^[^#]*\/(hypr|aquamarine|xdg-desktop-portal-hyprland)/d' "$f"
            note "removed the Hyprland lines from set @$(basename "$f") (old copy: $f.bak)"
        done
        note "Next, emerge lists everything it will remove: Hyprland plus anything only it used."
        note "Read the list before saying yes."
        if ! root emerge $ask --depclean; then
            warn "depclean stopped, so nothing was removed yet. Usually the system needs its updates first:"
            note "  doas emerge --ask --getbinpkg --update --newuse --deep --with-bdeps=y @world"
            note "then run this --cleanup again; it carries on from here."
            exit 1
        fi
    else
        note "no Hyprland packages installed"
    fi
    left=$(grep -rlsiE '/(hypr|aquamarine|xdg-desktop-portal-hyprland)' /etc/portage/package.* 2>/dev/null || true)
    [ -n "$left" ] && warn "Hyprland lines are still in: $(echo "$left" | tr '\n' ' ')(harmless; delete them if you like)"

    echo
    say "Hyprland is gone from this machine."
    note "Your hyprland-dotfiles repo on GitHub wasn't touched (the desktop still uses it)."
}

main "$@"
