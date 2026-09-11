#!/bin/bash
# Last step: remove Bazzite defaults we do not want, then tidy up build leftovers.
set -ouex pipefail

# --- Remove unwanted Bazzite packages ----------------------------------------
# waydroid  Android container; needs GPU support that NVIDIA does not offer.
# lutris    game launcher; Faugus Launcher (Flatpak) + umu-launcher is used instead.
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
    lutris

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

# Nothing we keep should still reference the removed binaries, and no
# Waydroid app-menu entry may survive.
test ! -e /usr/bin/waydroid
test ! -e /usr/bin/lutris
! ls /usr/share/applications/ | grep -qi waydroid

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
