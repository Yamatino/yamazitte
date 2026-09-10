#!/bin/bash
# Last step: remove things we do not want and tidy up.
set -ouex pipefail

# --- Planned: drop Waydroid (useless on NVIDIA) -------------------------------
# Not enabled yet. When ready, uncomment, push, and check the build log: dnf
# will refuse (and fail the build) if anything else still requires waydroid.
# Bazzite also ships helper bits around it that can go at the same time.
#
# dnf5 remove -y waydroid
# rm -f /usr/bin/waydroid-choose-gpu /usr/bin/waydroid-launcher
# rm -f /usr/share/applications/Waydroid.desktop

# Make sure no repo we enabled during the build is left enabled on the
# deployed system (nothing to do today; kept as the place to do it).

# Ensure the systemd unit the template enabled by default stays enabled.
systemctl enable podman.socket
