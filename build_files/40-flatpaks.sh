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
# (It also prints warnings about Citrix's ctxcwalogd.service: those are
# informational and not about our unit; only a non-zero exit fails the build.)
systemd-analyze verify "/usr/lib/systemd/system/${UNIT}"
# It leaves a marker file, /run/systemd/systemd-units-load, behind. /run is
# runtime-only (a tmpfs on the booted system) and `bootc container lint`
# fails the build if the image contains anything there, so drop it here,
# next to what created it. Same idea as /run/dnf in 90-cleanup.sh.
rm -rf /run/systemd

# `systemctl enable` in a container only creates the WantedBy symlink under
# /etc/systemd/system/multi-user.target.wants/, which is exactly what we want
# baked into the image (same as podman.socket in 90-cleanup.sh).
systemctl enable "${UNIT}"
