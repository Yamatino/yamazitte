# vim: set ft=make :
#
# yamazitte's own ujust recipes. Bazzite's /usr/share/ublue-os/justfile does
# `import? ".../60-custom.just"`: this file is the official hook for a custom
# image to add commands next to Bazzite's. Run `ujust --choose` to see them.

# Boot straight into a session. Sets the Plasma Login Manager autologin session for the current user. Options: niri (default) | plasma | status
[group("yamazitte")]
niri-autologin SESSION="niri":
    #!/usr/bin/bash
    set -euo pipefail
    # Plasma Login Manager (Bazzite's login screen) keeps autologin in
    # /etc/plasmalogin.conf: [Autologin] User= and Session=. The image can
    # preselect niri on the login screen (it does, see
    # /usr/lib/plasmalogin/plasmalogin.conf.d/50-yamazitte.conf) but cannot
    # set autologin, because that needs a username. This recipe does that
    # per-machine step. kwriteconfig6 edits the INI file in place, so any
    # other keys in it are left alone.
    CONF=/etc/plasmalogin.conf
    STALE=/etc/plasmalogin.conf.d/99-plasma-setup.conf
    SESSION="{{ SESSION }}"
    current_user="$(kreadconfig6 --file "$CONF" --group Autologin --key User 2>/dev/null || true)"
    current_session="$(kreadconfig6 --file "$CONF" --group Autologin --key Session 2>/dev/null || true)"
    if [[ "$SESSION" == "status" ]]; then
        if [[ -n "$current_user" ]]; then
            echo "Autologin: user '$current_user', session '${current_session:-<none: login screen>}'"
        else
            echo "Autologin: off (login screen)"
        fi
        exit 0
    fi
    case "$SESSION" in
        niri|plasma) ;;
        *) echo "Usage: ujust niri-autologin [niri|plasma|status]" >&2; exit 1 ;;
    esac
    test -f "/usr/share/wayland-sessions/${SESSION}.desktop"
    user="${current_user:-$USER}"
    sudo kwriteconfig6 --file "$CONF" --group Autologin --key User "$user"
    sudo kwriteconfig6 --file "$CONF" --group Autologin --key Session "$SESSION"
    # Leftover from Plasma's first-run wizard: it autologins a throwaway
    # 'plasma-setup' user and is meant to delete itself once setup finishes.
    # Harmless while the main file overrides it, but remove it so it can never
    # become active.
    if [[ -f "$STALE" ]] && ! id plasma-setup &>/dev/null; then
        sudo rm -f "$STALE"
    fi
    echo "Autologin set: user '$user' -> session '$SESSION'. Takes effect at next boot."
