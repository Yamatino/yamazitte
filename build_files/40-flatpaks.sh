#!/bin/bash
# Flatpaks that ship "with" the image.
#
# A bootc image cannot contain Flatpaks: they live in /var/lib/flatpak, which
# is machine state (see CLAUDE.md). What the image CAN carry is the *list* of
# apps it wants, in Flatpak's own preinstall format, plus a service that
# applies the list at boot. Both files come from system_files/:
#   /usr/share/flatpak/preinstall.d/yamazitte.preinstall   the list
#   /usr/lib/systemd/system/yamazitte-flatpak-preinstall.service   applies it
# This step only enables the service and checks the files are sane.
# To build without it, rename this file to 40-flatpaks.sh.disabled.
set -ouex pipefail

PREINSTALL=/usr/share/flatpak/preinstall.d/yamazitte.preinstall
UNIT=yamazitte-flatpak-preinstall.service

test -f "${PREINSTALL}"
test -f "/usr/lib/systemd/system/${UNIT}"

# The flatpak on the image must know the subcommand (flatpak >= 1.16). If a
# future base drops it, fail here with a clear message, not silently at boot.
flatpak preinstall --help >/dev/null

# Catch typos in the unit file now. systemd-analyze reads the unit from disk;
# it does not need a running systemd, which a container build does not have.
systemd-analyze verify "/usr/lib/systemd/system/${UNIT}"

# `systemctl enable` in a container only creates the WantedBy symlink under
# /etc/systemd/system/multi-user.target.wants/, which is exactly what we want
# baked into the image (same as podman.socket in 90-cleanup.sh).
systemctl enable "${UNIT}"
