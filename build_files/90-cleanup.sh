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
# wrappers, the "Force Restart Waydroid" app-menu entry, the pkexec helpers
# + polkit policy/rules it uses, and the Steam-library artwork directory
# (/usr/share/applications/Waydroid/*.png, referenced from Waydroid.desktop's
# X-Steam-Library-* keys). (Source: bazzite/system_files/desktop/shared.)
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
rm -rf /usr/share/applications/Waydroid

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
# Written as `if ...; then exit 1` on purpose: a bare `! command` does NOT
# abort under `set -e` (bash exempts negated commands from errexit), so the
# previous `! ls | grep` form could never fail the build. shellcheck SC2251.
test ! -e /usr/bin/waydroid
test ! -e /usr/bin/lutris
test ! -e /usr/bin/konsole
for leftover in waydroid konsole; do
    if find /usr/share/applications -iname "*${leftover}*" | grep -q .; then
        echo "ERROR: a ${leftover} app-menu entry survived the cleanup:" >&2
        find /usr/share/applications -iname "*${leftover}*" >&2
        exit 1
    fi
done
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

# Keep podman's API socket enabled (Bazzite ships it enabled; the ublue
# template repeats this so a custom image cannot lose it by accident). It is
# what lets tools talk to podman over /run/podman/podman.sock, e.g.
# Podman Desktop, `podman --remote`, and Docker-compatible clients.
systemctl enable podman.socket
