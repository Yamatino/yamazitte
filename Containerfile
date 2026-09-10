# ---------------------------------------------------------------------------
# Stage 1: "ctx" - a throwaway image that only holds our build inputs.
#
# `FROM scratch` is an empty image. We COPY the repo's build_files/ and
# system_files/ into it, and later bind-mount this stage into the real build
# at /ctx. Because it is only *mounted* (not COPYed) into the final image,
# none of these scripts end up in the OS you boot.
# ---------------------------------------------------------------------------
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# ---------------------------------------------------------------------------
# Stage 2: the actual OS image.
#
# Everything below runs on top of the same Bazzite image this machine already
# boots (bazzite-nvidia-open:stable, Fedora 44), so a `bootc switch` to the
# result is a small delta: same kernel, same drivers, plus our layers.
#
# `:stable` is a moving tag. The Justfile builds with --pull=newer, so each
# daily CI run (see .github/workflows/build.yml) picks up upstream Bazzite
# updates automatically. Pin to @sha256:... instead if you ever want a build
# that is reproducible against a specific upstream snapshot.
# ---------------------------------------------------------------------------
FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

# Bind-mount the ctx stage at /ctx and run the build.
#   type=bind,from=ctx   our scripts + system_files, read-only, not persisted
#   type=cache /var/cache, /var/log
#                        dnf metadata/rpm downloads and logs are kept between
#                        builds for speed AND kept OUT of the image: /var is
#                        machine state on bootc, not image content
#   type=tmpfs /tmp      scratch space (the Citrix RPM is downloaded here)
#                        that vanishes when the RUN finishes
#
# One RUN = one layer. All package installs happen inside it so the resulting
# image has a single customisation layer on top of Bazzite.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# bootc's own sanity check: fails the build on things that would break at
# deploy time, e.g. leftover files in /var without a tmpfiles.d rule,
# content in /tmp, a broken /etc, missing kernel, etc.
RUN bootc container lint
