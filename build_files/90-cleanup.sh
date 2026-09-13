#!/bin/bash
# Last step: remove Bazzite defaults we do not want, then tidy up build leftovers.
set -ouex pipefail

# --- Remove unwanted Bazzite packages ----------------------------------------
# waydroid  Android container; needs GPU support that NVIDIA does not offer.
# lutris    game launcher; Faugus Launcher (Flatpak) + umu-launcher is used instead.
# konsole   KDE's terminal; Ghostty (10-niri-noctalia.sh) is the image's only
#           terminal. Nothing in Bazzite depends on the package (checked with
#           `rpm -q --whatrequires konsole`); the two things that *call* it are
#           handled just below.
#
# clean_requirements_on_remove=False: dnf5 normally also removes packages that
# were pulled in only as dependencies of what you remove. Some of those (e.g.
# Wine/Proton bits Lutris depends on) are still wanted by tools we keep, and
# dnf cannot know that. Leaving them costs a little space and risks nothing.
#
# If a package we keep depends on one of these, dnf refuses and the build
# fails naming it; that is the safety net, so read the log rather than force.
dnf5 remove -y --setopt=clean_requirements_on_remove=False \
    waydroid \
    lutris \
    konsole \
    konsole-part

# Bazzite's own Waydroid integration is plain files, not part of the waydroid
# package, so dnf leaves it behind and it has to go by hand: the launcher
# wrappers, the "Force Restart Waydroid" app-menu entry and the pkexec helpers
# + polkit policy/rules it uses. (Source: bazzite/system_files/desktop/shared.)
# The ujust recipe file (82-bazzite-waydroid.just) stays: /usr/share/ublue-os/justfile
# imports it by name, and removing it would break every `ujust` command.
rm -f /usr/bin/waydroid-launcher \
      /usr/bin/waydroid-choose-gpu \
      /etc/default/waydroid-launcher \
      /usr/share/applications/waydroid-container-restart.desktop \
      /usr/libexec/waydroid-container-restart \
      /usr/libexec/waydroid-container-start \
      /usr/libexec/waydroid-container-stop \
      /usr/share/polkit-1/actions/org.bazzite.waydroid.policy \
      /usr/share/polkit-1/rules.d/30-waydroid.rules

# Two Bazzite bits still point at Konsole and are plain files, so dnf leaves
# them alone:
#  - /usr/bin/kde-ptyxis is a two-line shim from when Bazzite's terminal was
#    Ptyxis; it just execs konsole. Point it at Ghostty so any script or
#    desktop entry still calling it keeps working (both accept `-e cmd`).
#  - KDE apps (Dolphin's "Open Terminal", Kate...) read the terminal to use
#    from kdeglobals and default to konsole. /etc/xdg/kdeglobals is Bazzite's
#    file with its own settings, so edit it in place with kwriteconfig6
#    rather than overwriting it from system_files (same idea as policy.json).
cat > /usr/bin/kde-ptyxis <<'SHIM'
#!/usr/bin/bash
exec /usr/bin/ghostty "$@"
SHIM
chmod 0755 /usr/bin/kde-ptyxis
kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key TerminalApplication ghostty
kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop

# Nothing we keep should still reference the removed binaries, and no
# Waydroid/Konsole app-menu entry may survive.
test ! -e /usr/bin/waydroid
test ! -e /usr/bin/lutris
test ! -e /usr/bin/konsole
! ls /usr/share/applications/ | grep -qi waydroid
! ls /usr/share/applications/ | grep -qi konsole
grep -q '^TerminalApplication=ghostty$' /etc/xdg/kdeglobals

# --- Build leftovers ----------------------------------------------------------
# `bootc container lint` warns about these, and the Containerfile runs it with
# --fatal-warnings, so any leftover here fails the build:
#   /run/dnf             dnf's runtime state
#   /var/lib/dnf/repos   dnf repo bookkeeping
#   /run/selinux-policy  scratch files from the SELinux policy rebuild that the
#                        `dnf5 remove` above triggers (waydroid-selinux's
#                        uninstall scriptlet runs semodule, and Fedora's
#                        /var/run -> /run policy helper writes there)
# All are regenerated on first use; /run is a tmpfs on a booted system and
# /var is machine-local anyway, so nothing is lost by dropping them.
rm -rf /run/dnf /var/lib/dnf/repos /run/selinux-policy

# Ensure the systemd unit the template enabled by default stays enabled.
systemctl enable podman.socket
