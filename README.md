# yamazitte

A personal [bootc](https://bootc.dev) image: Bazzite (NVIDIA open driver, KDE base,
Fedora 44) plus the [niri](https://github.com/niri-wm/niri) scrollable-tiling
compositor with the [Noctalia](https://noctalia.dev) shell, and Citrix Workspace.
CI publishes it to `ghcr.io/yamatino/yamazitte:latest` on every push to `main` and
once a day, so upstream Bazzite updates flow through automatically.

The repo doubles as a set of notes on how bootc images work: every script and
config file explains *why* it does what it does. Start with `Containerfile`.

## Use it

```bash
sudo bootc switch ghcr.io/yamatino/yamazitte:latest   # then reboot
sudo bootc rollback                                     # undo, if needed
```

The image is signed with cosign; `cosign.pub` is the public key, and the image
teaches the booted system to verify future upgrades with it
(`build_files/30-image-signing.sh`).

On the login screen pick the **niri** session (it is preselected). `ujust niri-autologin`
boots straight into it. Under niri, `Mod+Shift+7` (Mod+? on a US layout) shows
the keybinds; `Mod+Space` is the launcher, `Mod+T` a Ghostty terminal.

## How the image is built

| Path | Role |
|---|---|
| `Containerfile` | The recipe. One `RUN` executes `build_files/build.sh` with the repo bind-mounted at `/ctx`, then `bootc container lint --fatal-warnings`. |
| `build_files/build.sh` | Copies `system_files/` onto `/`, then runs `NN-*.sh` in order. Add a step = add a numbered script; disable one = rename it `.disabled`. |
| `build_files/10-niri-noctalia.sh` | niri, Noctalia, portals, Ghostty; validates the niri config. |
| `build_files/15-niri-extras.sh` | Tools with no Fedora package (oniri), fetched with a pinned version + sha256. |
| `build_files/20-citrix.sh` | Citrix Workspace: installed from a GitHub Release asset, relocated from `/opt` to `/usr/lib/opt`. |
| `build_files/30-image-signing.sh` | Adds this image's cosign key to `/etc/containers/policy.json`. |
| `build_files/40-flatpaks.sh` | Enables the boot-time `flatpak preinstall` of the apps in `system_files/usr/share/flatpak/preinstall.d/`. |
| `build_files/90-cleanup.sh` | Removes Bazzite bits we do not want (Waydroid, Lutris, Konsole) and build leftovers. |
| `system_files/` | Files copied verbatim to the same path in the image. niri config lives in `etc/niri/`: `config.kdl` is upstream's default, `noctalia.kdl` the shell integration, `yamazitte.kdl` the image's own tweaks. |
| `image-template.env` | Image name/org used by the `Justfile` and CI. |

Two bootc rules shape most of the "odd" code here: `/usr` and `/etc` are image
content, `/var` (and `/opt`, a symlink into it) is machine state that upgrades
never touch, so nothing may ship under `/var`; and anything a script enables
(a COPR, a repo) must be disabled again before it ends.

## Customising niri without forking

`/etc/niri/config.kdl` ends with two optional includes, so you can override
anything without copying the file:

- `/etc/niri/local.kdl` for this machine (monitor layout, touchpad). Edits to
  `/etc` survive `bootc upgrade`.
- `~/.config/niri/local.kdl` for your user (binds, looks). Hot-reloads on save.

Both are used only while you do **not** have a `~/.config/niri/config.kdl`; niri
loads exactly one config file, and the per-user one wins.

## Developing

- One step, fast: `./dev-step.sh 20-citrix.sh` runs that script in a throwaway
  container from the base image and drops you into a shell to inspect. Needs
  podman on the host.
- Full build: `just build` (then `sudo bootc switch --transport containers-storage localhost/yamazitte:latest` to test it).
- CI status: `gh run list --limit 1`, failures: `gh run view --log-failed`.
- Every push to `main` triggers a ~15 minute rebuild that cancels any running
  one, so batch commits and push when a set is ready.

### Citrix RPM

Citrix's download page sits behind a EULA click, so the RPM is hosted as a
GitHub Release on this repo (tag `citrix`, asset `ICAClient-rhel-x86_64.rpm`, a
version-less name so the URL in `20-citrix.sh` never changes). To upgrade:

```bash
gh release upload citrix ICAClient-rhel-x86_64.rpm --clobber
```

## Origins and further reading

Started from [ublue-os/image-template](https://github.com/ublue-os/image-template),
whose README covers the generic parts (cosign key setup, the `Justfile`, disk/ISO
builds, S3 upload). Other niri bootc images worth reading:
[zirconium](https://github.com/zirconium-dev/zirconium),
[dltos](https://github.com/DataLabTechTV/dltos),
[babazzite](https://github.com/babariviere/babazzite),
[hyprblue](https://github.com/ashebanow/hyprblue).
