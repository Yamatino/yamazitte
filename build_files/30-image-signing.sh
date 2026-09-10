#!/bin/bash
# Teach the *booted* system to verify our own image's cosign signature.
#
# When you `bootc switch` to this image the first time, the policy of the
# currently running Bazzite is what gets enforced (it accepts unsigned images
# from registries other than ghcr.io/ublue-os). From then on, THIS policy is
# active, so every later `bootc upgrade` of ghcr.io/yamatino/yamazitte must be
# signed with the key in system_files/etc/pki/containers/yamazitte.pub, i.e.
# the SIGNING_SECRET the GitHub workflow signs with. A tampered or
# mis-published image is rejected instead of booted.
#
# Files involved (the first two come from system_files/):
#   /etc/pki/containers/yamazitte.pub          public half of cosign.key
#   /etc/containers/registries.d/yamazitte.yaml where to fetch signatures from
#   /etc/containers/policy.json                 which key must sign which image
set -ouex pipefail

IMAGE_REF="ghcr.io/yamatino/yamazitte"
KEY_PATH="/etc/pki/containers/yamazitte.pub"
POLICY="/etc/containers/policy.json"

test -f "${KEY_PATH}"
command -v jq >/dev/null || dnf5 install -y jq

# policy.json is shared with ublue's own entries (and podman!), so we edit it
# in place with jq rather than overwriting it from system_files.
jq --arg ref "${IMAGE_REF}" --arg key "${KEY_PATH}" \
   '.transports.docker[$ref] = [{
        "type": "sigstoreSigned",
        "keyPath": $key,
        "signedIdentity": { "type": "matchRepository" }
    }]' "${POLICY}" > /tmp/policy.json

# Never leave a broken policy.json behind: it would break podman/flatpak pulls too.
jq empty /tmp/policy.json
install -m 0644 /tmp/policy.json "${POLICY}"
