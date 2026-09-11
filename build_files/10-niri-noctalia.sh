#!/bin/bash
# niri (scrollable-tiling Wayland compositor) + Noctalia (desktop shell).
#
# Both are in the stock Fedora 44 repos, which Bazzite already has enabled, so
# no COPR is needed. Bazzite's login manager (Plasma Login Manager, an SDDM
# successor; config in /etc/plasmalogin.conf) lists any *.desktop in
# /usr/share/wayland-sessions, and the niri package ships one, so after the
# rebase "niri" simply appears as a session choice on the login screen.
set -ouex pipefail

# install_weak_deps=False: only pull what we list, not niri's "Recommends"
# (waybar, alacritty...). We list the ones we actually want explicitly.
dnf5 install -y --setopt=install_weak_deps=False \
    niri \
    xwayland-satellite \
    noctalia \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    gnome-keyring \
    alacritty \
    fuzzel \
    swaylock \
    brightnessctl \
    playerctl \
    wev
# Why each:
#   xwayland-satellite      X11 apps (Citrix included) under niri; niri >= 25.08
#                           launches it automatically when installed.
#   xdg-desktop-portal-*    niri ships /usr/share/xdg-desktop-portal/niri-portals.conf
#                           preferring gnome/gtk portals for screenshots/screencast/
#                           file pickers. Bazzite only has the KDE one. We override
#                           that file from system_files/etc/xdg-desktop-portal/ to
#                           pin FileChooser to gtk (see the comment there).
#   gnome-keyring           secrets portal backend used by niri-portals.conf.
#   alacritty/fuzzel/swaylock/brightnessctl/playerctl
#                           referenced by niri's default keybinds (Mod+T, Mod+D,
#                           Super+Alt+L, brightness keys, media play/next/prev).
#                           Bazzite ships none of them: Plasma has its own
#                           equivalents. Noctalia has its own launcher/lock on
#                           Mod+Space etc. so these are optional; drop them if
#                           you rebind.
#   wev                     prints key/mouse events; niri's config comments
#                           point to it for finding a key's XKB name.

# The system-wide config in /etc/niri/ (from system_files) already autostarts
# Noctalia, so a fresh user gets a working session without any dotfiles.
test -f /etc/niri/config.kdl
test -f /etc/niri/noctalia.kdl
test -f /etc/niri/yamazitte.kdl
# Referenced by spawn-at-startup in yamazitte.kdl; provided by kwallet-pam.
test -x /usr/libexec/pam_kwallet_init
# tray-launch (system_files) needs gdbus from glib2.
command -v gdbus >/dev/null
test -x /usr/bin/tray-launch
# ujust niri-autologin (system_files 60-custom.just) needs the KDE config tools.
command -v kwriteconfig6 >/dev/null
command -v kreadconfig6 >/dev/null
# A syntax error in 60-custom.just would break every ujust command: parse the
# whole justfile (which imports it) now rather than on the user's machine.
just -f /usr/share/ublue-os/justfile --list >/dev/null

# Sanity-check that the config parses with the niri we just installed.
# `niri validate` exits non-zero on syntax/unknown-option errors.
niri validate -c /etc/niri/config.kdl
