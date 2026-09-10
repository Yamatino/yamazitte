# yamazitte

Custom bootc image: `ghcr.io/ublue-os/bazzite-nvidia-open:stable` (Fedora 44) plus
niri + Noctalia and Citrix Workspace. Published by CI to `ghcr.io/yamatino/yamazitte:latest`.
The owner is learning bootc/Containerfiles through this repo: explain the *why* of
changes, and keep scripts commented so the repo itself teaches.

## Layout

- `Containerfile` — the OS recipe. One `RUN` calls `build_files/build.sh` with the
  repo mounted at `/ctx` (never copied into the image). Ends with `bootc container lint`.
- `build_files/build.sh` — overlays `system_files/` onto `/`, then runs `NN-*.sh` in order.
  Add a step = add a numbered script. Disable a step = rename it (e.g. `.disabled`).
- `system_files/` — files copied verbatim to the same path in the image (`etc/`, `usr/`).
  niri config: `etc/niri/config.kdl` is upstream's default untouched except two `include`s;
  Noctalia bits go in `noctalia.kdl`, image-wide tweaks (keybinds) in `yamazitte.kdl`.
- `image-template.env` — image name/org used by the Justfile and CI. Do not edit the Justfile.

## Rules that come from bootc

- `/usr` and `/etc` are image content. `/var` is machine state and is NOT updated on
  `bootc upgrade`/`switch`. Never leave files under `/var` in the image; use
  `/usr/lib/...` plus a `tmpfiles.d` rule (see `20-citrix.sh` + `usr/lib/tmpfiles.d/citrix.conf`).
- `/opt` is a symlink to `/var/opt`, so packages installing into `/opt` need the same
  relocation. Do not use `rm /opt && mkdir /opt`.
- Disable any COPR you enable during the build before the script ends.
- `/etc/containers/policy.json` is shared with ublue's entries and podman; edit it with
  `jq` (`30-image-signing.sh`), never overwrite it from `system_files/`.

## Citrix

The RPM is not scriptable from Citrix's site. It is a GitHub Release asset on this repo:
tag `citrix`, asset `ICAClient-rhel-x86_64.rpm` (version-less name so the URL in
`20-citrix.sh` never changes). Upgrade with
`gh release upload citrix ICAClient-rhel-x86_64.rpm --clobber`. `*.rpm` is gitignored.

## Verifying

- Single step, fast (needs podman, i.e. on the Bazzite host, not a sandbox):
  `./dev-step.sh 20-citrix.sh` runs that script in a throwaway container from the base
  image and leaves you in a shell to inspect. Prefer this for iterating on one script.
- Full build: `just build`
- Pushing to `main` cancels any in-progress CI run (concurrency group), so batch commits
  while a run you care about is still going.
- CI: `gh run list --limit 1` / `gh run view --log-failed`
- Rebase: `sudo bootc switch ghcr.io/yamatino/yamazitte:latest`; undo with `sudo bootc rollback`
- niri config is validated at build time by `niri validate -c /etc/niri/config.kdl`

## Secrets / keys

`cosign.key` is gitignored and must never be committed. `cosign.pub` is committed and
also shipped into the image at `/etc/pki/containers/yamazitte.pub`.
