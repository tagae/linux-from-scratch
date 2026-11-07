Contributing
============

Overview
--------

* `lfs`: CLI frontend
* `lib/`: LFS framework
* `lib/category/`: the helpers of the recipes of a package category, loaded for them alone
* `platform/`: the machines that systems run on
* `capability/`: what systems can support, as kernel configuration fragments: optional ones, and the userland's own
* `feature/`: tool sets for the systems' users, as lists of packages
* `package/`: package recipes
* `download/`: fetched archives
* `source/`: unpacked sources
* `work/`: build dirs, and the sysroots of the cross toolchains
* `tools/`: toolchains
* `install/`: target install trees, one per system key
* `archive/`: package tarballs, each with its SHA-256 digest
* `image/`:  disk images
* `Makefile`: build rules, run directly on a Linux host; the `docker-` goals run them through Docker
  Compose instead, up to the image
* `Dockerfile.{bootstrap,scratch}`: build containers (for reproducibility)
* `test`: boot tester

The `lfs` CLI frontend invokes the sub-commands implemented in `lib/*.sh`.


Building the Toolchain
----------------------

### Bootstrap

Relies on the host for the initial set of tools used to bootstrap our own. The following command
builds a cross-compiler plus a native, relocatable set of temporary tools (bash, coreutils, make,
wget, ...) into the `tools` directory.

```shell
./lfs tools bootstrap
```

### Scratch

Self-hosted using only what `tools bootstrap` staged. The following command adds
build-host-only tooling (Python, meson/ninja, kmod, btrfs-progs, ...) into the `tools` directory:

```shell
./lfs tools build
```

With this the tools are fully functional and can be used to build packages.


Building the System
-------------------

The following command builds the system for the platform into `install/$SYSTEM_KEY`, starting from
an empty tree. It first builds a cross toolchain, as chapter 5 of the LFS book does: binutils, a
first gcc, the Linux API headers and glibc, then the full cross gcc. The base system from chapter 8
is then compiled with that toolchain, followed by the kernel, configured from the layers that
every system gets (`package/linux/`: base, hardening, machine and architecture) and from the
system's capabilities (`capability/`, the userland's own included), then the packages of the
system's features. Each package is installed both into the
system tree and into the toolchain's sysroot, `work/<platform>-<userland>/sysroot`, which also
receives what compiling against the packages needs: the Linux API headers and the packages' `dev`
components. The kernel is also copied to `work/boot/$SYSTEM_KEY`, where QEMU on the host finds it.

```shell
./lfs system build
```


Images
------

* The `./lfs image build` command makes a disk image from the install tree at
  `install/$SYSTEM_KEY`, as populated by `./lfs system build`. Given a block device instead of an
  image file, it partitions the device and fills it the same way, with the root file system taking
  all of the space the boot partition leaves.
* The `./lfs qemu` command boots the built image through a qcow2 overlay next to it,
  `<image>.qcow2`, which takes what the system writes. The overlay is made anew with the image, and
  its size is a power of two, as QEMU requires of an SD card.

Nothing is mounted: `mkfs.btrfs --rootdir` makes the root file system from a copy of the install
tree, and mtools fills the FAT boot partition. For an image file, each file system is made in a
file of its own, the root file system as small as its files allow, then copied into the image,
behind its partition table. The copy gives the system's files to root, so making an image needs
root, e.g. `sudo --preserve-env ./lfs image build`, which is what `make image` runs (or the scratch
container as root, e.g. `docker compose run --rm --user 0:0 scratch ./lfs image build`, as
`make docker-image` does). Making a system on a device erases it, so that takes `ERASE`, set to the
same device, e.g. `sudo ERASE=/dev/sdb ./lfs image build /dev/sdb`, on a Linux host: the scratch
container is not privileged, and has no access to devices. A device that anything has mounted or
opened is refused (unmount a card from a desktop's automounter first). The programs that make
the image (`mkfs.btrfs`, `mkfs.fat`, mtools, `sfdisk`) are the tools', as for every build.


Package Model
-------------

Each `package/<name>.sh` runs in a fresh subshell that predefines the hooks
`fetch`/`prepare`/`build`/`install`/`archive`/`unarchive` with sane defaults. `install` runs into
an empty stage, so an archive holds exactly what it installed. The default `archive` records the
archive's SHA-256 digest next to it, and the default `unarchive` installs an archive only if it
still matches.

A package's name is the path of its recipe under `package/`, without the `.sh`. The Python libraries
live in `package/python/` and are named `python/<name>`, after their PyPI project without any
`python-` prefix, e.g. `lfs_system_install python/click`.

The directory of a package's name is its category (`python` for `python/click`, `.` for `bash`).
The framework puts everything of the package in the category's directory of `download/`,
`source/`, `work/<key>/` and `archive/<key>/`: its downloads and patches, its unpacked sources (a
recipe cannot set `package_source_dir` elsewhere), its build, stage and component directories, and
its archives. Packages of different categories therefore never share a path, whatever their names,
versions or files are called: `python/foo` and `foo` can coexist. A recipe that fetches or unpacks
by hand uses the same directories.

A category can have helpers for its recipes in `lib/category/<category>.sh`
(`lib/category/python.sh` for `python`), which the framework loads for the recipes of that category
and for no others. A recipe that uses them belongs to the category, whatever it installs:
`python/yubikey-manager` is a program.

A recipe changes an upstream source file with a patch, never by editing the file: `patch_source URL
sha256:...` fetches and applies one, and `apply_patch` applies one kept in the package's files
directory (`package/<name>/<change>.patch`, made with `diff -u` against the pristine file, so that
it applies with `-p1`, and starting with the reason for the change). Each patch is applied once to
an unpacked source.

A package may list other packages in `package_fetch_dependencies`, whose sources it needs to build.
The framework fetches them before building the package, and exposes their locations as
`<dependency>_source_dir`.

The `package_license` list the package's license in [SPDX format][SPDX License List].

A package's install can set its development files (headers, static libraries, pkg-config files...)
aside for its `dev` component with `move_to_dev_component` (see `lib/components.sh`), which is
installed only where wanted: into build trees, not into systems. Systems ship without documentation,
so a package's install also sets aside its man and info pages and whatever it installs under
`/usr/share/doc` with `move_to_docs_component`, for a `docs` component that nothing makes a package
of; wanting it again takes a `docs` branch in the recipes' install, like `dev`'s. Programs and
libraries are stripped as they are linked. The system carries readers for man and info pages: `man`
from mandoc, which needs zlib, and `info` from texinfo, of which only the reader and `install-info`
are built.


Conventions
-----------

All shell code should be POSIX compliant.

### External API

Shell variables are part of the **external API** if they are used to parameterise `lfs`.

External API variables have uppercase names (e.g., `PLATFORM`, `USERLAND`, `CAPS`, `FEATURES`)

They are the only variables of its environment that `lfs` passes on to builds, along with `PATH`
and `TMPDIR` (the list is `lfs_environment`, in `lfs`): every command but `qemu` and `help`
starts anew in an environment that holds them alone, as a container would, and has a home of its
own, `WORK_DIR`. After `tools bootstrap`, which builds the first tools with the host's, `PATH`
holds the tools' directories alone, and their trust store serves the downloads: nothing of the
host's (a program, a config script, an interpreter) finds its way into a build, on a Linux host
as in the scratch container.

External API variables might be exported in invocations of `lfs`, but are never exported internally
as part of internal logic.

### Internal API

Shell variables are part of the **internal API** if they are used by functions, and are not part of
the external API (e,g. `package_version`, `prefix`).

Internal API variables have lowercase names.

Internal API variables must not be exported.

### Encapsulation

A recipe owns the functions it defines: no other recipe, and no feature, calls them, as that would
make a package depend on the inside of another. What several recipes need is a helper in
`lib/<topic>.sh`, sourced by `lfs` (`lib/meson.sh`), or in `lib/category/<category>.sh`, loaded for
the recipes of that package category (`lib/category/python.sh`). A feature may define helpers of
its own, for its own use, but never one that a package uses: packages rely on the framework
(`lib/`) alone.


### Simplicity

The simplest codebase, with the fewest conditionals: a uniform rule beats a special-cased default.
Remove duplication where it appears, and prove that the result is unchanged.

### Comments

A comment says why the code is as it is now, in the present tense, briefly, in the density of the
surrounding code. It never tells how things were or will be: no "previously", "formerly", "no
longer", "used to", "still", "instead of", "fixed", no "kernels before 7.3 ...", no incident that
led to the code, and no history that a commit message carries. Where the code must differ between
the versions or platforms built today, a comment names the one that needs it ("the pi0's kernel
selects SYSCTL through PROC_SYSCTL"), not what came before or after. This holds for every comment
and every patch description.

### Framework Changes

A change to the framework (`lib/*.sh`, `Makefile`, `Dockerfile.*`, `docker-compose.yaml`, `lfs`)
starts from its design, shown before the change is made, unless the change is what was asked for.
The archive step only archives. Features are written on request, not speculatively.


Where Code Goes
---------------

| What | Where |
|---|---|
| One package's build | `package/<name>.sh`: `case $package_component`, `default_*` for the rest |
| Files shipped verbatim | `package/<name>/<path as installed>`, copied by `install` |
| A capability (kernel support) | `capability/<cap>.config`: a fragment, with a `# Requires: <cap>...` line for the capabilities it builds on |
| What a feature installs | `feature/<feature>.sh`: flat `lfs_system_install X` (+ `lfs_install_package X#dev` for build-time files), in dependency order, with a `# Requires: <cap>...` line |
| Helpers of one feature | in its file, for its own use: no package uses them (see Encapsulation) |
| Helpers several recipes share | `lib/<topic>.sh`, sourced in `lfs` (`lib/meson.sh`), or `lib/category/<category>.sh` for a package category, loaded for that category's recipes alone; recipe-facing names are plain (`meson_cross_file`, `move_to_dev_component`), framework functions are `lfs_*` (`lfs_tools_install`, `lfs_system_install`) |
| Kernel options every system needs | `package/linux/{base,hardening,<machine>,<arch>}.config`, each with its reason |
| Kernel options that are optional, or the userland's | `capability/<cap>.config` (`capability/<userland>.config` comes with the userland), each with its reason |
| A change to an upstream source file (a device tree included) | a patch in `package/<name>/`, applied by `apply_patch` in `prepare`; a recipe never edits a source file with `sed` or `cat >>`. The Pi's device tree is `package/linux/<board>.patch`, which appends override nodes (later definitions win) |
| Static users and groups | `package/system-files/systemd-gnu/etc/{passwd,group,shadow}` |

A capability is what the system supports (a kind of device), a feature a tool set for users. A
capability installs no packages; a feature touches no kernel option: a kernel need becomes a
capability the feature requires. The system gets the required capabilities along (the key leaves
them out). Features require capabilities only and install in alphabetical order, each in a subshell;
one that needs another's packages installs them itself. Each file's header says what it enables and
how it changes the others. Build-machine tools that a system build needs (swig, the Rust seed,
native Python modules) are installed into `TOOL_DIR` from the feature with
`lfs_tools_install <package>`, archived `*-tools-*`, never shipped.


Writing Recipes
---------------

Read two recipes like yours before starting: copy idioms, not ideas.

* Use the upstream's own targets and options (`headers_install`, meson options, `make install`)
  over re-implementing them; add the missing tool rather than a workaround.
* Link dynamically; static only where dynamic complicates things (gcc's in-tree gmp, mpfr and mpc).
* No documentation: no man, info, doc, locale or NLS files; the install calls
  `move_to_docs_component`. No empty directories in a system, except mount points. Real hardware
  comes first: the Pi's boot partition is firmware, `config.txt`, `cmdline.txt` and a flat device
  tree blob.
* Pin everything: `package_source_hash=sha256:<hex>` of the tarball, checked against the upstream's
  digest or PyPI's JSON API; patches via `patch_source URL sha256:...`.
* `package_license` is in SPDX for every recipe, from the real LICENSE files, bundled code
  included (Rust crates too).
* A file that another package installs is changed in that package's install (`system-files` is
  merged first, and the last file wins).


systemd
-------

* No presets run. A unit is enabled as `systemctl enable` does it: the recipe makes the symlink
  under `/etc/systemd/system/<target>.wants/`, with an absolute target in
  `/usr/lib/systemd/system`; a symlink under `/usr/lib` reads as "disabled" to `is-enabled`.
* The image bakes a machine ID (`lib/image.sh`): the first boot is ordinary, and a first-boot
  `preset-all` would only warn about generated units. Images are per build, not per card.
* There is no D-Bus, PAM, polkit or logind, and passwd is static: services run as root unless the
  user exists in the static files. Where upstream's unit needs a dedicated user or
  `PrivateUsers=full`, ship a small unit of our own (`pcscd.service`). Prefer socket activation
  (`--auto-exit`).
* The `sysctl.d` file `50-default.conf` is rewritten in `systemd.sh`.
* A new service leaves `is-system-running` at `running`, `--failed` empty, and nothing new at
  warning level.


Kernel
------

The kernel is configured from `allnoconfig` and fragments. Write down every option relied on, even
the ones that default to y, and the parents that gate a menu (`USB_SUPPORT`, `NET`,
`NETWORK_FILESYSTEMS`, `NETDEVICES`: each bit once). Find dependencies in the Kconfig, which
`tar --include` extracts from the tarball, and verify the resolved `.config`, never the fragment.
Archives are named by package and version, not by content: after a change, delete the `linux-*`
archive of every key that must pick it up (`.github/ci/invalidate` does so for CI's cache).

Pi facts:

* The USB power domain needs `CONFIG_PM` and `RASPBERRYPI_POWER`, else dwc2 probes ten seconds
  late.
* `KUSER_HELPERS` is required by libatomic, which OpenSSL's libraries link on ARMv6: an eager
  `dlopen` of libcrypto faults without it.
* `HW_RANDOM_BCM2835` and `COMPAT_32BIT_TIME` are set.
* DMA stays off, for the regression of the bcm2835-dma driver in 6.18.
* virt takes USB (xHCI), RNG (virtio-rng) and its console (`hvc0`) from `virt.config`.


Cross-Compiling
---------------

* pkg-config: `PKG_CONFIG_LIBDIR`, which replaces the path, never `PKG_CONFIG_PATH`. pkgconf
  prefixes the sysroot onto absolute-path `.pc` variables unless `PKG_CONFIG_FDO_SYSROOT_RULES=1`,
  which is needed where meson reads them as install directories (pcsc-lite, ccid).
* meson: `meson_cross_file`; wipe the build directory first; pin what meson takes from the build
  machine (libdir, split-bin, uid ranges).
* autotools: `--host` and `--build`; cache values only for tests that cannot run. `*-config`
  scripts leak build paths (pass an absolute override, as `gnupg.sh` does with `GPGRT_CONFIG`); old
  configure tests break under C23 (`-std=gnu17` for gmp, gnupg, flex); libtool `.la` files in the
  sysroot misdirect later builds (delete them); guard same-arch cross builds, where `build` equals
  `host`.
* Python (CPython 3.14, `python` and `dev` components): extensions and wheels are built by the
  `TOOL_DIR` Python against the target's sysconfigdata (`lib/category/python.sh`: `python_wheel` and
  `python_install_wheel` for a build backend, `python_install_modules` for pure Python,
  `python_site_packages`; templates `package/python/cffi.sh` and `package/python/pycparser.sh`).
  Recipes never mention `python_version`, which the framework sets. Bytecode is precompiled
  unchecked-hash so that the Pi never writes `__pycache__`; no pip, and no dist-info unless
  metadata is read at run time. The default `package_source_dir` is right unless the sdist's
  directory is spelled differently from the name (`more_itertools-...`): then the recipe sets it,
  with `python/` in it.
* Rust: the seed is in `TOOL_DIR` (`package/rust.sh`, `lfs_tools_install rust`); the triple is
  `$target_arch-unknown-$target_kernel-$target_abi`; crates are fetched at fetch time and built
  `--locked --offline`; `--remap-path-prefix` keeps build paths out of panics; binaries are
  stripped.
* ARMv6: no `-march` or `-mcpu` overrides from a build system's guesses (`readelf -A` shows no
  v7-only instructions); 32-bit atomics are inline, 64-bit ones go through libatomic (shipped by
  `gcc#runtime`).
* An ELF file that carries a build-machine path (RPATH, debug sections, panic strings) is a defect.

### Platforms with the Build Machine's Own Triple

On virt and arm64, built on an aarch64 Mac, the triple is `aarch64-unknown-linux-gnu`, the build
machine's, though the compiler is the cross `aarch64-scratch-linux-gnu-gcc`: tools that compare
triples see a native build. For `cryptography`:

* cargo has one linker setting per triple, shared by build scripts and proc-macros (which run on the
  build machine; `rust.sh`'s `cargo` wrapper points them at the tools' compiler) and by the
  platform's code. With equal triples the cross linker is silently replaced, and the extension
  links against the tools' glibc with its RPATH. The cross linker goes to the single compilation
  that links the platform's code: `cargo rustc ... --lib -- -C linker=$host-gcc`.
* The `cc` crate reads `CC_<triple_with_underscores>`, then `HOST_CC` if the triples are equal, else
  `TARGET_CC`, then `CC`: set `CC_<triple>` and `AR_<triple>`.
* pyo3 detects cross builds by comparing triples: set `PYO3_CROSS=1` with `PYO3_CROSS_LIB_DIR`.
* The `TOOL_DIR` Python and the platform's share a multiarch name: select the sysconfigdata by name
  and by path (`python_wheel` sets `_PYTHON_SYSCONFIGDATA_NAME` and `_PATH`).
* Only ARM32 needs `KUSER_HELPERS`, libatomic's need for it, and 32-bit time.

A recipe is proven on a platform with a different triple (pi0) and on one with the same (virt):
check the extension's `readelf -d` (RPATH, NEEDED).


Before Calling a Change Done
----------------------------

1. The package's archive is deleted and the package rebuilt, and the build log shows the rebuild
   and no error.
2. No library is newly needed but unshipped; `readelf -A` is right; licences and hashes are
   verified.
3. The system boots in QEMU: the standard checks are clean, and the feature is exercised with
   emulated devices.
4. The real build command, run again, is a no-op.
5. Comments are timeless and nothing is duplicated; no test leftovers remain under `image/`,
   `work/` or the repository; the README is updated when user-visible behaviour changed.
6. The report names what was not verified (hardware, PINs, speed) and any framework change that it
   proposes.

Gotchas
-------

Mind that ash/dash's `A | B` does not fail the pipeline if `A` fails.


Pointers
--------

- https://www.raspberrypi.com/documentation/computers/processors.html
- http://www.dettus.net/detLFS/
- https://www.linux-magazine.com/Issues/2021/245/detLFS
- https://blog.jgosmann.de/posts/2021/02/07/a-guide-to-crosscompiling-applications/


[SPDX License List]: https://spdx.org/licenses/
