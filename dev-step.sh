#!/bin/bash
# Run one or more build steps in a throwaway container, without building the image.
#
#   ./dev-step.sh 20-citrix.sh              run one step
#   ./dev-step.sh 10-niri-noctalia.sh 20-citrix.sh
#   ./dev-step.sh                           just open a shell in the base image
#
# Mirrors the Containerfile: the base image from FROM, the repo mounted at /ctx
# (build_files/ at /ctx, system_files/ at /ctx/system_files), system_files
# overlaid onto / first, and a tmpfs on /tmp. Nothing is committed: the
# container is deleted on exit. Needs podman (run this on the Bazzite host, not
# in a sandbox). Use `just build` for a full-fidelity build.
set -euo pipefail

cd "$(dirname "$0")"
BASE_IMAGE="$(sed -n 's/^FROM[[:space:]]\+\([^[:space:]]\+\)[[:space:]]*$/\1/p' Containerfile | grep -v '^scratch' | tail -1)"
echo ">> base image: ${BASE_IMAGE}"

STEPS=("$@")
if [[ ${#STEPS[@]} -eq 0 ]]; then
    INNER='exec bash'
else
    INNER='set -ouex pipefail; cp -avf /ctx/system_files/. / >/dev/null'
    for s in "${STEPS[@]}"; do
        INNER+="; echo '>> running ${s}'; bash /ctx/${s}"
    done
    INNER+="; echo '>> all steps OK - dropping you into a shell to inspect (exit to discard)'; exec bash"
fi

# :ro,Z  read-only mount with an SELinux label podman can use
# --tmpfs /tmp   same as the Containerfile's tmpfs mount
exec podman run --rm -it \
    -v "./build_files:/ctx:ro,Z" \
    -v "./system_files:/ctx/system_files:ro,Z" \
    --tmpfs /tmp \
    "${BASE_IMAGE}" \
    bash -c "${INNER}"
