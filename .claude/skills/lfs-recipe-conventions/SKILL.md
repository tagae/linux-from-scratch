---
name: lfs-recipe-conventions
description: Rules for writing or changing recipes, capabilities, features, kernel fragments and framework helpers in this LFS framework - the user's preferences, where each kind of code goes, naming, pinning and licences, systemd and kernel idioms, cross-compilation idioms (meson, Python, Rust, same-triple platforms), ARMv6 pitfalls, and the checklist before calling a change done. Use before adding or editing anything under package/, lib/ or package/linux/. Read CONTRIBUTING.md too; this adds what it does not say.
model: sonnet
---

# Writing recipes, capabilities and features here

CONTRIBUTING.md has the package model (hooks, components, uppercase external / lowercase internal never-exported
variables, POSIX shell, the ash/dash pipeline gotcha). Read two recipes like yours before starting: copy idioms,
not ideas. Building and verifying: lfs-build-iteration. Booting: qemu-image-testing.

## The user's preferences (they override your taste)

- SIMPLICITY: the simplest codebase, the fewest conditionals; a uniform rule beats a special-cased default.
  Remove duplication when asked, and prove the result unchanged.
- COMMENTS state the current rationale only, timeless: no "previously", "instead of", "fixed", no incident stories.
  They say WHY, briefly, in the density of the surrounding code.
- FRAMEWORK CHANGES (lib/*.sh, Makefile, Dockerfile.*, docker-compose.yaml, lfs): show the design first unless
  asked for that change. The archive step only archives. Shared helpers get their own `lib/<topic>.sh`, sourced in
  `lfs`. Features on request, not speculatively.
- ENCAPSULATION: the functions a recipe or feature defines are its own; no other recipe calls them. What several
  recipes need goes in `lib/<topic>.sh`. A feature never defines a helper that a package uses: packages rely on the
  framework (`lib/`) alone.
- Use the upstream's own targets and options (headers_install, meson options, `make install`) over re-implementing;
  add the missing tool rather than a workaround.
- Link DYNAMICALLY (static only where dynamic complicates things: gcc's in-tree gmp/mpfr/mpc).
- NO DOCS: no man/info/doc/locale/NLS: the install calls `move_to_docs_component`. No empty directories in a system
  (mount points only). Real hardware first: the Pi boot partition is firmware, `config.txt`, `cmdline.txt`, a flat DTB.
- Pin everything: `package_source_hash=sha256:<hex>` of the tarball you downloaded, checked against the upstream's
  digest or PyPI's JSON API; patches via `patch_source URL sha256:...`.
- `package_license` in SPDX for every recipe, from the real LICENSE files, bundled code included (Rust crates too).
- Ask in plain text, not with the question tool. Decide small things by these rules and report them; put framework
  changes and real trade-offs to the user.

## Where code goes

| What | Where |
|---|---|
| One package's build | `package/<name>.sh`: `case $package_component`, `default_*` for the rest |
| Files shipped verbatim | `package/<name>/<path as installed>`, copied by `install` |
| A capability (kernel support) | `capability/<cap>.config`: a fragment, with a `# Requires: <cap>...` line for the capabilities it builds on |
| What a feature installs | `feature/<feature>.sh`: flat `lfs_system_install X` (+ `lfs_install_package X#dev` for build-time files), in dependency order, with a `# Requires: <cap>...` line |
| Helpers of one feature | in its file, for its own use: no package uses them (encapsulation, above) |
| Helpers several recipes share | `lib/<topic>.sh` sourced in `lfs` (`lib/meson.sh`, `lib/python.sh`); recipe-facing names are plain (`meson_cross_file`, `move_to_dev_component`), framework functions are `lfs_*` (`lfs_tools_install`, `lfs_system_install`) |
| Kernel options every system needs | `package/linux/{base,hardening,<machine>,arch-<arch>}.config`, each with its reason |
| Kernel options that are optional, or the userland's | `capability/<cap>.config` (`capability/<userland>.config` comes with the userland), each with its reason |
| Device tree changes | override nodes appended in `package/linux.sh` `prepare` (later definitions win) |
| Static users and groups | `package/system-files/systemd-gnu/etc/{passwd,group,shadow}` |

A capability is what the system supports (a kind of device), a feature a tool set for users. A capability installs no
packages; a feature touches no kernel option: a kernel need becomes a capability the feature requires. The system
gets the required capabilities along (the key leaves them out). Features require capabilities only and install in
alphabetical order, each in a subshell; one that needs another's packages installs them itself. Each file's header
says what it enables and how it changes the others. Build-machine tools a system build needs (swig, the Rust seed,
native Python modules) are installed into TOOL_DIR from the feature with `lfs_tools_install <package>`, archived
`*-tools-*`, never shipped.

## systemd here

- No presets run. Enable a unit as `systemctl enable` does: the recipe makes the symlink under
  `/etc/systemd/system/<target>.wants/` (absolute target in /usr/lib/systemd/system); a /usr/lib symlink reads as
  "disabled" to `is-enabled`.
- The image bakes a machine ID (lib/image.sh): the first boot is ordinary; first-boot preset-all would only warn
  about generated units. Images are per build, not per card.
- No D-Bus, PAM, polkit or logind; static passwd: services run as root unless the user exists in the static files.
  Where upstream's unit needs a dedicated user or `PrivateUsers=full`, ship a small unit of your own (pcscd.service).
  Prefer socket activation (`--auto-exit`).
- A file another package installs is changed in that package's install (system-files merges first; sysctl.d's
  50-default.conf is rewritten in systemd.sh).
- A new service must leave `is-system-running` = `running`, `--failed` empty, nothing new at warning level.

## Kernel (allnoconfig + fragments)

Write down every option you rely on, even "default y" ones, and the parents that gate a menu (USB_SUPPORT, NET,
NETWORK_FILESYSTEMS, NETDEVICES: each bit once). Find dependencies in the Kconfig (`tar --include`) and verify
the RESOLVED `.config` with `kernel-config`, never the fragment. After a change delete the `linux-*` archive of
every key that must pick it up. Pi facts: the USB power domain needs `CONFIG_PM` + `RASPBERRYPI_POWER` (else dwc2
probes ten seconds late); `KUSER_HELPERS` is required by libatomic (linked by OpenSSL's libraries on ARMv6; an
eager dlopen of libcrypto faults without it); `HW_RANDOM_BCM2835`; `COMPAT_32BIT_TIME`; DMA stays off (6.18
bcm2835-dma regression). virt takes USB (xHCI), RNG (virtio-rng) and console (`hvc0`) from `virt.config`.

## Cross-compiling

- pkg-config: `PKG_CONFIG_LIBDIR` (replaces the path), never `PKG_CONFIG_PATH`. pkgconf prefixes the sysroot onto
  absolute-path .pc variables unless `PKG_CONFIG_FDO_SYSROOT_RULES=1` (needed where meson reads them as install
  directories: pcsc-lite, ccid).
- meson: `meson_cross_file`; wipe the build directory first; pin what meson takes from the build machine (libdir,
  split-bin, uid ranges).
- autotools: `--host`/`--build`; cache values only for tests that cannot run. Recorded earlier: `*-config` scripts
  leak build paths (pass an absolute override, as gnupg.sh does with `GPGRT_CONFIG`); old configure tests break under
  C23 (`-std=gnu17` for gmp, gnupg, flex); libtool `.la` in the sysroot misdirect later builds (delete them); guard
  same-arch cross builds, where `build` equals `host`.
- Python (CPython 3.14, `python` + `dev` components): extensions and wheels are built by the TOOL_DIR Python against
  the target's sysconfigdata (`lib/python.sh`: `python_wheel` and `python_install_wheel` for a build backend,
  `python_install_modules` for pure Python, `python_site_packages`; templates `package/python/cffi.sh` and
  `package/python/pycparser.sh`). Recipes never mention `python_version`, which the framework sets. Bytecode is
  precompiled unchecked-hash so the Pi never writes `__pycache__`; no pip, no dist-info unless metadata is read at run
  time. A Python library's recipe is `package/python/<name>.sh`, installed as `python/<name>`: its PyPI name without a
  `python-` prefix (programs stay at the top: `yubikey-manager`, `meson`). The framework keeps downloads, patches,
  sources, work directories and archives under `python/` (the package's group), and rejects a `package_source_dir`
  outside it; the default is right unless the sdist's directory is spelled differently from the name
  (`more_itertools-…`): then set it, with `python/` in it. A recipe that fetches by hand uses the group's directory.
- Rust: the seed in TOOL_DIR (`package/rust.sh`, `lfs_tools_install rust`); triple
  `$target_arch-unknown-$target_kernel-$target_abi`; crates fetched at fetch time, built `--locked --offline`;
  `--remap-path-prefix` keeps build paths out of panics; stripped.
- ARMv6: no `-march`/`-mcpu` overrides from a build system's guesses (`readelf -A`, no v7-only instructions);
  32-bit atomics inline, 64-bit through libatomic (shipped by gcc#runtime).
- An ELF file carrying a build-machine path (RPATH, debug sections, panic strings) is a defect.

### Platforms with the build machine's own triple (virt, arm64 on an aarch64 Mac)

The triple is `aarch64-unknown-linux-gnu`, the build machine's, though the compiler is the cross
`aarch64-scratch-linux-gnu-gcc`, so tools that compare triples see a native build. For `cryptography`:
- cargo has ONE linker setting per triple, shared by build scripts and proc-macros (run on the build machine;
  `rust.sh`'s `cargo` wrapper points them at the tools' compiler) and by the platform's code. With equal triples the
  cross linker is silently replaced and the extension links against the tools' glibc with its RPATH. Give the cross
  linker to the single compilation that links the platform's code: `cargo rustc ... --lib -- -C linker=$host-gcc`.
- The `cc` crate reads `CC_<triple_with_underscores>`, then `HOST_CC` if the triples are equal, else `TARGET_CC`,
  then `CC`: set `CC_<triple>` and `AR_<triple>`.
- pyo3 detects cross builds by comparing triples: set `PYO3_CROSS=1` with `PYO3_CROSS_LIB_DIR`.
- The TOOL_DIR Python and the platform's share a multiarch name: select the sysconfigdata by name AND path
  (`python_wheel` sets `_PYTHON_SYSCONFIGDATA_NAME` and `_PATH`).
- ARM32-only: KUSER_HELPERS, libatomic's need for it, 32-bit time.
A recipe is proven on a platform with a different triple (pi0) AND one with the same (virt); check the extension's
`readelf -d` (RPATH, NEEDED).

## Before saying "done"

1. Archive deleted, package rebuilt, `build-summary` shows the rebuild, no errors.
2. `missing-libs` has no new line; `readelf -A` right; licences and hashes verified.
3. Booted (qemu-image-testing): standard checks clean, the feature exercised with emulated devices.
4. The real build command run again is a no-op.
5. Comments timeless, no duplication, no test leftovers under `image/`, `work/` or the repo; README, qemu-image-testing's
   `reference/pi0-real-boot.md` and memory updated when user-visible behaviour changed.
6. The report names what was not verified (hardware, PINs, speed) and any framework change you would propose.
