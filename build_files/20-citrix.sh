#!/bin/bash
# Citrix Workspace app (ICAClient) baked into the image.
#
# Two problems to solve here:
#
# 1. Citrix's download page requires clicking through a EULA, so the RPM has
#    no stable, scriptable URL. We host the RPM ourselves and download it at
#    build time from CITRIX_RPM_URL (see README section below on how to
#    publish it as a GitHub Release asset).
#
# 2. The RPM installs into /opt/Citrix. On bootc, /opt -> /var/opt, and /var
#    is *machine state*, not image content: it is populated once on first
#    install and never touched by `bootc upgrade`/`switch` again. Anything the
#    image leaves in /var/opt would be missing after the rebase. So we move it
#    to /usr/lib/opt (immutable image content, same trick rpm-ostree uses for
#    layered packages) and let a tmpfiles.d rule
#    (system_files/usr/lib/tmpfiles.d/citrix.conf) recreate the
#    /var/opt/Citrix symlink every boot.
set -ouex pipefail

# Where to fetch the RPM. Download "Citrix Workspace app for Linux, RPM,
# x86_64 (RHEL-based)" from https://www.citrix.com/downloads/workspace-app/linux/
# then publish it as a GitHub Release asset with a version-less filename, so
# this URL stays valid when you upgrade Citrix later:
#   cp ICAClient-rhel-*-0.x86_64.rpm ICAClient-rhel-x86_64.rpm   # e.g. ICAClient-rhel-gcc-8-26.04.10.1-0.x86_64.rpm
#   gh release create citrix ICAClient-rhel-x86_64.rpm --title "Citrix Workspace RPM" --notes "RPM consumed by the image build"
# To upgrade: gh release upload citrix ICAClient-rhel-x86_64.rpm --clobber
CITRIX_RPM_URL="${CITRIX_RPM_URL:-https://github.com/Yamatino/yamazitte/releases/download/citrix/ICAClient-rhel-x86_64.rpm}"

# To build without Citrix, rename this file to 20-citrix.sh.disabled
# (build.sh only runs NN-*.sh).

# /tmp is a tmpfs mount in the Containerfile, so the RPM never ends up in the image.
RPM=/tmp/ICAClient.rpm
if ! curl -fsSL --retry 3 -o "${RPM}" "${CITRIX_RPM_URL}"; then
    cat >&2 <<MSG
ERROR: could not download the Citrix RPM from
  ${CITRIX_RPM_URL}
Download "Citrix Workspace app for Linux (RPM, x86_64, RHEL-based)" from
https://www.citrix.com/downloads/workspace-app/linux/ and publish it as a
GitHub Release asset at that URL (see comments in build_files/20-citrix.sh).
MSG
    exit 1
fi

# --- Dependencies -----------------------------------------------------------
# The RPM is built for RHEL and declares `Requires: webkit2gtk3 >= 2.26`, the
# RHEL *package name* for WebKitGTK's legacy 4.0 API. Fedora never used that
# name and (since F42) does not ship the 4.0 API at all, only 4.1/6.0, so dnf
# cannot resolve it: "nothing provides webkit2gtk3".
#
# What actually needs it (checked with the binaries' DT_NEEDED entries):
#   wfica          the session engine that opens .ica files -> GTK3 only
#   selfservice    Citrix's "store browser" GUI            -> libwebkit2gtk-4.0.so.37
# Everything the day-to-day workflow uses (browser -> launch -> .ica -> wfica)
# works without WebKit. Only the selfservice store GUI is unavailable on
# Fedora, which is the same situation every Fedora 42+ user is in.
#
# So: let dnf install every dependency that really exists, then install the
# RPM itself with rpm --nodeps, which skips only the dependency *check*.
# (The list mirrors the RPM's Requires minus webkit2gtk3; `rpm -qpR` shows it.)
dnf5 install -y --setopt=install_weak_deps=False \
    gtk2 gtk3 \
    libICE libSM libX11 libXext libXinerama libXmu libXpm libXrender libXt \
    libpng libva speexdsp sqlite-libs

# Fedora has no /usr/lib/x86_64-linux-gnu (that is Debian/Ubuntu's layout).
# Remember whether it exists, because Citrix's post-install script will create it (below).
MULTIARCH_DIR=/usr/lib/x86_64-linux-gnu
HAD_MULTIARCH_DIR=0
[[ -e "${MULTIARCH_DIR}" ]] && HAD_MULTIARCH_DIR=1

# --nodeps: skip dependency checking only; scriptlets and file installs run
# normally. The %post scriptlet runs /opt/Citrix/ICAClient/util/integrate.sh,
# which creates the .desktop symlinks and registers the .ica MIME type.
rpm -Uvh --nodeps "${RPM}"

# integrate.sh also tries to "help" with WebKit: if libwebkit2gtk-4.0.so.37 is
# missing it untars a bundled *Ubuntu* build of it into / (Ubuntu paths, Ubuntu
# library versions). Those files are useless on Fedora and are not on the
# linker path anyway, so drop them and the 45 MB tarball itself.
[[ "${HAD_MULTIARCH_DIR}" == 0 ]] && rm -rf "${MULTIARCH_DIR}"
rm -rf /usr/share/lintian \
       /usr/share/doc/libwebkit2gtk-4.0-37 \
       /usr/share/doc/libjavascriptcoregtk-4.0-18
rm -rf /opt/Citrix/ICAClient/Webkit2gtk4.0

# Don't advertise the GUI that cannot run: remove its app-menu entry.
# (The hidden x-scheme-handler entries and wfica.desktop, which handles .ica
# files, stay.)
rm -f /usr/share/applications/selfservice.desktop

# Make the system CA bundle visible to Citrix. ICAClient only trusts certs in
# its own keystore, which is the #1 cause of "SSL error 61 / You have not
# chosen to trust ..." on Linux. Fedora's ca-certificates ships every CA as an
# individual, OpenSSL-hash-named file here, which is exactly what ICAClient wants.
ICAROOT=/opt/Citrix/ICAClient
CA_DIR=/etc/pki/ca-trust/extracted/pem/directory-hash
if [[ -d "${CA_DIR}" && -d "${ICAROOT}/keystore/cacerts" ]]; then
    shopt -s nullglob   # an empty glob iterates zero times instead of the literal "*.pem"
    for pem in "${CA_DIR}"/*.pem; do
        ln -sf "${pem}" "${ICAROOT}/keystore/cacerts/"
    done
    # Regenerate the hash symlinks Citrix uses for lookup (ships with ICAClient).
    if [[ -x "${ICAROOT}/util/ctx_rehash" ]]; then
        "${ICAROOT}/util/ctx_rehash"
    fi
fi

# Relocate out of /var (see header). /opt is a symlink to /var/opt, so the RPM
# actually wrote to /var/opt/Citrix.
mkdir -p /usr/lib/opt
mv /var/opt/Citrix /usr/lib/opt/Citrix

# Temporarily put a symlink where the directory was, so we can self-check that
# the main binary is reachable the way Citrix expects (/opt -> /var/opt -> /usr/lib/opt)
# and that every shared library it links against is present. Because we
# bypassed rpm's dependency check, this ldd check is what proves wfica can run.
ln -s /usr/lib/opt/Citrix /var/opt/Citrix
test -x "${ICAROOT}/wfica"
if ldd "${ICAROOT}/wfica" | grep -q "not found"; then
    echo "ERROR: wfica has unresolved libraries:" >&2
    ldd "${ICAROOT}/wfica" | grep "not found" >&2
    exit 1
fi

# ...and take it away again: nothing in /var should ship in the image. The
# tmpfiles.d rule creates this exact symlink on every boot of the real system.
rm /var/opt/Citrix
