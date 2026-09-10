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

# Bazzite's Waydroid helpers are plain files, not packages, so remove them by hand.
# The ujust recipe file (82-bazzite-waydroid.just) stays: /usr/share/ublue-os/justfile
# imports it by name, and removing it would break every `ujust` command.
rm -f /usr/bin/waydroid-launcher /usr/bin/waydroid-choose-gpu

# Nothing we keep should still reference the removed binaries.
test ! -e /usr/bin/waydroid
test ! -e /usr/bin/lutris

# --- Build leftovers ----------------------------------------------------------
# `bootc container lint` warns about these: dnf's runtime state under /run and
# repo bookkeeping under /var/lib. Both are regenerated on first use, and /run
# and /var are machine-local anyway, so nothing is lost by dropping them.
rm -rf /run/dnf /var/lib/dnf/repos

# Ensure the systemd unit the template enabled by default stays enabled.
systemctl enable podman.socket
