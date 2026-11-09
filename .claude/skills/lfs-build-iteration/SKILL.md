---
name: lfs-build-iteration
description: Build, rebuild and verify systems of this LFS framework from the Mac (Docker via Colima) - system keys, archives and volumes, which stale state to delete after changing a recipe, kernel fragment or framework file, running long builds, inspecting images and volumes, proving a refactor changed nothing. Use before and during any change to package/*.sh, lib/*.sh, package/linux/*.config or a feature. Booting the result is qemu-image-testing; the conventions for writing the recipe are in CONTRIBUTING.md.
model: sonnet
---

# Building and verifying in this repo

Paths are from the repo root; `B=.claude/skills/lfs-build-iteration/scripts`.

## Keys, archives, volumes

- A system is `<platform>-<init>[+<feature>...]`, features in ALPHABETICAL order
  (`pi0-systemd+fido2+gnupg+yubikey-manager`; lfs bails on `+usb`: a fragment is no feature). A feature is
  `feature/<feature>.sh`; a `# Linux:` line names every kernel fragment (`package/linux/<fragment>.config`) it
  relies on, a `# Requires:` line the features it builds on. Everything after the cross toolchain is a feature:
  the init is one (`INIT=systemd`: kmod, libxcrypt, shadow, ncurses, util-linux, systemd; it requires `bash` and
  names the `systemd` fragment; the rest of chapter 8 is `+gnu+man+procps+tzdata`), and the
  platform file's `# Requires:` line names its own (`linux`; `pi-boot` on pi0); lfs bails on naming one in the
  key. lfs resolves `base_features` (the init's and the platform's), `features` (the others, each after what it
  requires) and `linux_fragments` (those of all features, sorted).
- Build: `make docker-image/<key>.img` (Linux hosts: `make image/<key>.img`); also `make image PLATFORM=pi0
  FEATURES="b c"`. Result: `image/<key>.img` and `work/boot/<key>/{kernel.img,*.dtb}`.
- Packages are archived once: `archive/<package_key>/<name>-<version>[-component].tar.xz` + `.sha256`. The
  package key is the base key (`pi0-systemd`) extended AS IT STOOD WHEN THE PACKAGE WAS BUILT: the
  toolchain's and the base features' packages (init, Pi firmware/boot) are shared by all systems; the kernel sits
  under the base key plus ALL the fragments of the features, sorted (`pi0-systemd+hidraw+systemd+usb+usb-storage`;
  `pi0-systemd+systemd` with no other feature), shared by systems whose features need the same fragments; another
  feature's packages under the base key plus the features up to it (`pi0-systemd+fido2+gnupg`). Build-machine
  packages are `<name>-tools-<version>`.
- A recipe re-runs ONLY when its archive is missing. Editing a recipe, patch, kernel fragment or installed file
  changes nothing until you delete its archive (`command rm archive/<key>/<name>-*`: tarball, `.sha256`, `-dev`).
  After a kernel fragment delete `linux-*.tar.xz*` of EVERY key that must change: those with the fragment, or all of
  them for a layer, base keys included.
  Packages after the deleted one are not rebuilt unless their own archive is gone.
- `lfs system build` (run by every `make docker-*`) wipes `install/<key>` and rebuilds it from archives: even a
  no-op takes 3-4 minutes and ends with the image step (`image (done)` when nothing changed). The image is remade
  only when a file of the install tree is newer than it or its SBOM (`image/<key>.spdx.json`, which `lib/sbom.sh`
  writes from `work/sbom/<key>`, the list of packages `lfs_system_install` recorded) is missing, and archives keep
  their files' times: after changing `lib/image.sh` or `lib/sbom.sh`, delete the image and its SBOM
  (`image/<key>.img`, `image/<key>.spdx.json`; the QEMU overlay `<key>.qcow2` follows the image). Validate the SBOM
  with `pyspdxtools --infile` (`pip install spdx-tools` in a venv).
- NEVER run two builds at once, of any keys or platforms, yours or an agent's: check `ps aux | grep -E
  '[m]ake docker|[d]ocker compose run'`. Every build re-extracts the tools into the shared `tools` volume,
  overwriting tools another build is running (`Bus error (core dumped)` in `rm`/`sed` during a configure, silently
  failing tests, nonsense follow-on errors), and all keys of a platform and init share and wipe one sysroot
  (`work/pi0-systemd/sysroot`).
- `system-files` is merged BEFORE the other packages and the last file wins: a file a package installs cannot be
  overridden from `package/system-files`; change it in that package.
- Sources and `work/` build directories persist: meson reconfigures a configured directory with its OLD options
  and compilers (the meson recipes wipe theirs in `prepare`); patches are stamped `.patched-*`, so a patch you
  change is not applied again to a source that has it: delete that source directory.
- The kernel `.config` is regenerated from `allnoconfig` + fragments at every `prepare`; allnoconfig drops options
  that default to y (KUSER_HELPERS, COMPAT_32BIT_TIME, ...): set them, then confirm with `$B/kernel-config KEY
  OPTION...` (the resolved lines, from the volume).

## Run a build

```sh
$B/build-image KEY LOGDIR   # background; prints "pid N log PATH"; refuses if a build is running
$B/wait-pid N               # "finished" or "still running", before the tool's 600 s limit; call again
$B/build-summary LOG        # errors, "compiled" (0 = only archives used), how it ended
```
Wait on the PID: `pgrep -f make` in a wait loop matches itself. `sleep N; other` in one Bash call is blocked
(use `until ...; do sleep 5; done`). The network is needed only for missing sources. Minutes for a kernel plus a
few packages; a cold system takes over half an hour. Do not commit or push unless asked (signing needs the
user's YubiKey touch).

## Docker, Colima, the Mac shell

- Colima shares only `$HOME`: `docker run -v /tmp/x:/x` mounts an EMPTY directory. Keep files in the repo or pipe
  a script: `docker run --rm -i IMG sh -s -- args < script`.
- Volumes `linux-from-scratch_{source,work,tools,install}`; images `linux-from-scratch-dev` (Debian: readelf,
  python3, dash; for inspecting) and `linux-from-scratch-scratch` (only the tools). Inspect read-only:
  `docker run --rm -v linux-from-scratch_work:/w:ro linux-from-scratch-dev ls /w/<key>`.
- The Bash tool's shell is zsh with `cp mv rm` aliased `-i` (`command rm`; `/bin/cp -c` for APFS clones, GNU cp
  has none), GNU coreutils first (`stat -c`, `sed -i` without `''`), bsdtar (`--include`, no `--wildcards`). The
  user's shell is fish.
- Read upstream sources without unpacking all: `tar -xzf download/X.tar.gz -C <new empty dir> --include
  '*/path'` (Kconfig, devicetree, meson options, units).

## Check what a build produced

- `$B/missing-libs KEY`: needed-but-unshipped libraries and RPATHs outside /usr/lib. Only NEW lines matter: the
  header lists the known base ones (shadow and util-linux build-path RPATHs). Dlopened libraries are invisible.
- `readelf -A` (pi0: ARM v6KZ + VFP; `objdump -d | grep -E 'movw|movt|dmb|sdiv|ubfx'` must be empty), `readelf -d`.
- Inside an image, nothing booted: the scratch container is not privileged, the dev container is. As root in dev,
  `losetup -r -f --show -o $((START * 512)) --sizelimit $((SIZE * 512)) image/<key>.img` with START and SIZE from
  `sfdisk -d` (the tools' `/mnt/lfs/tools/usr/sbin/sfdisk`: dev has none), then `mount -o ro`. A read-only
  mount of a shrunk btrfs reports 0 available: `df` in the booted system is the real figure.
- Boot: qemu-image-testing.

## Prove a refactor changed nothing

1. lib/*.sh: `git show HEAD:lib/x.sh > OLD`; `$B/env-trace OLD lib/x.sh 'lfs_tools_build'` runs both under bash and
   dash with `lfs_install_package` stubbed to print the variables that matter. IDENTICAL for both shells and every
   driver means the environment of every install is unchanged (archives exist, so a rebuild alone would not run it).
2. Generated text (cross file, unit): extract the old text from `git show`, produce the new, `cmp`.
3. Rebuild the affected packages: copy their archives away, delete them, `build-image`, then `python3 -I
   $B/archive-manifest.py A.tar.xz > m` for old and new and `diff` (paths, modes, content hashes, symlink targets).
4. Boot and the standard checks are as before.
Say which of these ran.

## Traps

- A build that "passes" while a recipe is stale: ask which archive the change must invalidate.
- A no-op build has no compile lines (`compiled: 0`).
- A failure that makes no sense (sed's gnulib-tests wanting `windows.h` because the `ioctl` configure test died
  with `Bus error` in `rm`) is first a COLLISION: rerun alone before debugging; look for `Bus error`,
  `Segmentation fault`, `core dumped` ahead of the first compiler error.
- virt (aarch64 on an aarch64 Mac) is a cross build between different triples that triple-comparing tools see as
  native (CONTRIBUTING.md): a recipe proven for pi0 is not proven for virt, nor the reverse. Build both.
- `work/boot/<key>/` is per key: trust only the key you built.
