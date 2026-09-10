#!/bin/bash
# Small niri helper tools that are not packaged in Fedora.
#
# No RPM or COPR exists, so they are fetched from GitHub at build time,
# pinned to an exact version AND a sha256, for two reasons:
#   - reproducibility: a daily rebuild must not silently pick up new code
#   - integrity: a release asset or raw file on GitHub is not signed by anyone
#     we verify, so the checksum is what ties this build to code we reviewed.
# To upgrade: bump the version, download the new file, compute `sha256sum`,
# update the hash here. `./dev-step.sh 15-niri-extras.sh`
# checks it in seconds.
set -ouex pipefail

# Downloads $2 to $3 and fails the build unless its sha256 is $1.
fetch_verified() {
    local sha="$1" url="$2" dest="$3"
    curl -fsSL --retry 3 -o "${dest}" "${url}"
    echo "${sha}  ${dest}" | sha256sum --check --strict
}

# --- oniri: maximise the only window on a workspace ---------------------------
# https://github.com/Antiz96/oniri (GPL-3.0). Static musl binary from the
# release; the author also publishes the .sha256 and a GPG signature, and the
# hash below matches their published one. With -T ("tiling layout") the
# window is un-maximised again when a second one opens, so a single window
# fills the monitor but two windows tile as usual. Started for every niri
# session from /etc/niri/yamazitte.kdl.
ONIRI_VERSION=1.3.5
fetch_verified \
    6667d3f053f40227a4e4b4b46bda848be63159ab27d76f001e9cd736e15e440d \
    "https://github.com/Antiz96/oniri/releases/download/v${ONIRI_VERSION}/oniri-${ONIRI_VERSION}-x86_64" \
    /usr/bin/oniri
chmod 0755 /usr/bin/oniri
/usr/bin/oniri --version
