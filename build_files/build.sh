#!/bin/bash
# Entry point called from the Containerfile. Runs inside the image being built,
# as root, with this repo's build_files/ and system_files/ bind-mounted at /ctx.
#
#   -o pipefail : a failing command in a pipe fails the pipe
#   -u          : unset variables are errors
#   -e          : any failing command aborts the build (so a broken step can't
#                 silently produce a half-configured image)
#   -x          : echo every command to the build log
set -ouex pipefail

# 1. Overlay system_files/ onto the root filesystem.
#    Anything you put in system_files/etc or system_files/usr lands at the same
#    path in the image. This is how we ship config files (niri, tmpfiles,
#    signing policy) without writing them from a script.
cp -avf "/ctx/system_files"/. /

# 2. Run each customisation step in order. Numbering makes the order obvious
#    and lets you disable a step by renaming it (e.g. 20-citrix.sh.disabled).
for script in /ctx/[0-9][0-9]-*.sh; do
    echo "::group::Running ${script}"
    bash "${script}"
    echo "::endgroup::"
done
