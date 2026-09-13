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
    gnome-keyring-pam \
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
#                           It is also the Secret Service every browser and
#                           Flatpak stores passwords in on this image.
#   gnome-keyring-pam       unlocks the login keyring with the password you
#                           typed at the login screen. Plasma Login Manager's
#                           PAM stack (/usr/lib/pam.d/plasmalogin) already
#                           calls it, but with a leading "-", which means "skip
#                           silently if the module is not installed" -- and it
#                           is only a *Recommends* of gnome-keyring, so
#                           install_weak_deps=False above skipped it. The
#                           result was a locked keyring on every boot and a
#                           "keyring is locked" dialog the first time Chrome
#                           wanted a password. Naming it explicitly is the fix.
#   playerctl               media keys (play/next/prev) in niri's default binds.
#                           Bazzite ships none of these small tools: Plasma has
#                           its own equivalents.
#   fuzzel/swaylock/brightnessctl
#                           what niri's *stock* binds for Mod+D, Super+Alt+L and
#                           the brightness keys call. /etc/niri/noctalia.kdl
#                           rebinds those keys to Noctalia's launcher, lock and
#                           OSD, so these three are fallbacks for a session where
#                           Noctalia is not running (run them from a terminal or
#                           `niri msg action spawn -- swaylock`). Drop them if
#                           you never want that safety net. (Mod+T's terminal
#                           is Ghostty, below.)
#   wev                     prints key/mouse events; niri's config comments
#                           point to it for finding a key's XKB name.

# Ghostty is the image's one terminal (Mod+T in /etc/niri/yamazitte.kdl; Konsole
# is removed in 90-cleanup.sh). It is not in Fedora proper but in Terra, a
# third-party repo Bazzite ships pre-configured but *disabled*, key included
# (/etc/yum.repos.d/terra.repo). --enablerepo turns it on for this one command
# only, so the repo stays disabled in the image: nothing else ever pulls from
# it by accident, and the CLAUDE.md rule "disable what you enable" is
# satisfied without a second step. The package also pulls in ghostty-terminfo.
dnf5 install -y --setopt=install_weak_deps=False --enablerepo=terra ghostty
command -v ghostty >/dev/null

# The system-wide config in /etc/niri/ (from system_files) already autostarts
# Noctalia, so a fresh user gets a working session without any dotfiles.
test -f /etc/niri/config.kdl
test -f /etc/niri/noctalia.kdl
test -f /etc/niri/yamazitte.kdl
# Referenced by spawn-at-startup in yamazitte.kdl; provided by kwallet-pam.
test -x /usr/libexec/pam_kwallet_init
# The PAM module that unlocks the login keyring; see the comment above. The
# plasmalogin PAM stack references it optionally, so a missing file is silent:
# check for it here instead of discovering it as a password prompt at login.
test -f /usr/lib64/security/pam_gnome_keyring.so
# Also spawned from yamazitte.kdl: KDE's polkit agent (package polkit-kde),
# the only thing that draws password prompts for admin actions under niri.
# Fedora installs KDE Frameworks 6 helpers under /usr/libexec/kf6/, not
# /usr/libexec/ (the first build of this check failed on exactly that).
test -x /usr/libexec/kf6/polkit-kde-authentication-agent-1
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
