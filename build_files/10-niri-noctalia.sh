#!/bin/bash
# niri (scrollable-tiling Wayland compositor) + Noctalia (desktop shell).
#
# Both are in the stock Fedora 44 repos, which Bazzite already has enabled, so
# no COPR is needed. Bazzite's SDDM lists any *.desktop in
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
    brightnessctl
# Why each:
#   xwayland-satellite      X11 apps (Citrix included) under niri; niri >= 25.08
#                           launches it automatically when installed.
#   xdg-desktop-portal-*    niri ships /usr/share/xdg-desktop-portal/niri-portals.conf
#                           preferring gnome/gtk portals for screenshots/screencast/
#                           file pickers. Bazzite only has the KDE one.
#   gnome-keyring           secrets portal backend used by niri-portals.conf.
#   alacritty/fuzzel/swaylock/brightnessctl
#                           referenced by niri's default keybinds (Mod+T, Mod+D,
#                           Super+Alt+L, brightness keys). Noctalia has its own
#                           launcher/lock on Mod+Space etc. so these are optional;
#                           drop them if you rebind.

# The system-wide config in /etc/niri/ (from system_files) already autostarts
# Noctalia, so a fresh user gets a working session without any dotfiles.
test -f /etc/niri/config.kdl
test -f /etc/niri/noctalia.kdl
test -f /etc/niri/yamazitte.kdl

# Sanity-check that the config parses with the niri we just installed.
# `niri validate` exits non-zero on syntax/unknown-option errors.
niri validate -c /etc/niri/config.kdl
