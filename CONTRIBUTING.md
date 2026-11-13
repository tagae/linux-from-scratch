Contributing To This Project
============================

Overview
--------

* `lfs`: CLI frontend
* `lib/`: framework implementation; contains the `lfs` subcommands
* `platform/`: the platforms that systems run on
* `profile/`: system recipes
* `package/`: package recipes
* `download/`: fetched archives
* `source/`: unpacked sources, per profile (e.g., `source/pi0-pgp`) and tools (`source/tools`)
* `work/`: build dirs, and the sysroots of the cross toolchains
* `tools/`: built tools and cross toolchain for each platform
* `install/`: target install trees, per profile
* `archive/`: package tarballs and SHA-256 digests
* `image/`:  built disk images
* `invalidate`: deletes the archives that a change makes stale
* `check/`: the checks (`make lint`, `make sbom-check`, `make vulnerability-check`), with a Makefile
  that the main one includes
* `Makefile`: build rules
* `Dockerfile.{bootstrap,scratch,dev}`: build and dev containers (for reproducibility)
* `test`: boot tester


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

The following command builds the system of the profile into `install/$PROFILE`, starting from an
empty tree. It first builds a cross toolchain, as chapter 5 of the LFS book does: binutils, a first
gcc, the Linux API headers and glibc, then the full cross gcc. Everything else comes from the
profile, `profile/$PROFILE.sh`, compiled with that toolchain: the packages of the system in the
order they are installed, the init (`systemd`, with the strict minimum of chapter 8 that it needs,
and `dash`, root's shell, which it requires) and the kernel (`linux`, configured from the layers
that every system gets, `package/linux/`: base, platform and architecture, and from the
capabilities that the profile names, `package/linux/<capability>.config`) among them. Each package is
installed both into the system tree and into the toolchain's sysroot, `work/$PROFILE/sysroot`, which
also receives what compiling against the packages needs: the Linux API headers and the packages'
`dev` components. The kernel is also copied, with the platform's device tree, to
`work/boot/$PROFILE`, where QEMU on the host finds it.

```shell
./lfs system build
```


Images
------

* The `./lfs image build` command makes a disk image from the install tree at
  `install/$PROFILE`, as populated by `./lfs system build`. Given a block device instead of an
  image file, it partitions the device and fills it the same way, with the root file system taking
  all of the space the boot partition leaves.
* An image file gets its SBOM next to it, `<image>.spdx.json` (`lib/sbom.sh`): an SPDX 2.3 document
  in JSON with the image's SHA-256 and the upstream packages it holds, each with its version, SPDX
  licence, the URL and SHA-256 of its source, and its CPE or PyPI package URL, which vulnerability
  scanners match (CI's scan is `.github/workflows/vulnerabilities.yaml`). The system
  build lists the packages in `$WORK_DIR/sbom/$PROFILE` as `lfs_system_install` installs them,
  and `image build` writes the document from that list. An image counts as built only along with
  its SBOM. A block device gets none, as it is no file to take the digest of.
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
still matches. Archives are named by package and version, not by content, so a package builds again
only when its archive is gone: `make invalidate` (`make docker-invalidate` for the build through
Docker) deletes the ones that what has changed since its last run makes stale, uncommitted changes
included. The header of `invalidate` holds the rules. A package built against one that changed is
not dropped with it.

A package's name is the path of its recipe under `package/`, without the `.sh`. The Python libraries
live in `package/python/` and are named `python/<name>`, after their PyPI project without any
`python-` prefix, e.g. `lfs_system_install python/click`.

The directory of a package's name is its category (`python` for `python/click`, `.` for `bash`).
The framework puts everything of the package in the category's directory of `download/`,
`source/<key>/`, `work/<key>/` and `archive/<key>/`: its downloads and patches, its unpacked sources (a
recipe cannot set `package_source_dir` elsewhere), its build, stage and component directories, and
its archives. Packages of different categories therefore never share a path, whatever their names,
versions or files are called: `python/foo` and `foo` can coexist. A recipe that fetches or unpacks
by hand uses the same directories.

A category can have helpers for its recipes in `lib/<category>.sh` (`lib/python.sh` for
`python`), which the framework loads for the recipes of that category and for no others. A recipe
that uses them belongs to the category, whatever it installs: `python/yubikey-manager` is a
program. A category is named unlike the framework's own files (`lib/system.sh`, `lib/meson.sh`...),
which its recipes would load again.

A recipe changes an upstream source file with a patch, never by editing the file: `patch_source URL
sha256:...` fetches and applies one, and `apply_patch` applies one kept in the package's files
directory (`package/<name>/<change>.patch`, made with `diff -u` against the pristine file, so that
it applies with `-p1`, and starting with the reason for the change). Each patch is applied once to
an unpacked source.

A package may list other packages in `package_fetch_dependencies`, whose sources it needs to build.
The framework fetches them before building the package, and exposes their locations as
`<dependency>_source_dir` (`libgpg_error_source_dir` for `libgpg-error`).

The `package_license` list the package's license in [SPDX format][SPDX License List]. A licence that
the list does not have is a `LicenseRef-<name>`, whose text is the file
`package/<package>/LicenseRef-<name>.txt`, which the SBOM carries and `check/lint` looks for.

The SBOM gives each package the CPE under which the NVD lists its vulnerabilities,
`part:vendor:product:version`: by default `a:<vendor>:<name>:<version>`, where the vendor is the
owner of the source's project on GitHub or GitLab, or else the name of the site that serves the
source (`gnu` for `ftp.gnu.org`). A recipe whose package the NVD names otherwise sets
`package_cpe` to its CPEs, separated by spaces, or to `none` where the NVD has none:
`: ${package_cpe:=a:systemd_project:systemd:$package_version}`. A package from PyPI has no CPE, but
a PyPI package URL (`lib/sbom.sh`).

A package's install can set its development files (headers, static libraries, pkg-config files...)
aside for its `dev` component with `move_to_dev_component` (see `lib/components.sh`), which is
installed only where wanted: into build trees, not into systems. Systems ship without documentation,
so a package's install also sets aside its man and info pages and whatever it installs under
`/usr/share/doc` with `move_to_docs_component`, for a `docs` component that nothing makes a package
of. The exception is `man=yes` and `info=yes`, which a platform (`platform/pi0.sh`) or a profile
sets for the systems it builds: `move_to_docs_component` then leaves the man or the info pages in the
package. A recipe that has to be told to build them says `: ${man:=no}` and reads it (`openssl`,
`libfido2`), or asks `docs_wanted` for either (`gnupg` and its libraries: `--$doc-doc`). The tools
never have them: `lib/tools.sh` and `lfs_install_tool` set `man=no info=no`. Programs and libraries
are stripped as they are linked.


Conventions
-----------

All shell code should be POSIX compliant.

### External API

Shell variables are part of the **external API** if they are used to parameterise `lfs`.

External API variables have uppercase names (e.g., `PROFILE`, `TIMEZONE`, `IMAGE_SIZE`)

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

A recipe owns the functions it defines: no other recipe, and no profile, calls them, as that would
make a package depend on the inside of another. What several recipes need is a helper in
`lib/<topic>.sh`, sourced by `lfs` (`lib/meson.sh`), or in `lib/<category>.sh`, loaded for the
recipes of that package category (`lib/python.sh`). A profile may define helpers of its own, for its
own use, but never one that a package uses: packages rely on the framework (`lib/`) alone.


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
The archive step only archives. Profiles are written on request, not speculatively.

### Markdown Conventions

* Prefer ASCII art.
  * In particular, prefer underlined headers over `#` and `##`.
  * Align table dividers so that they look fine in plain text.


Where Code Goes
---------------

| What | Where |
|---|---|
| One package's build | `package/<name>.sh`: `case $package_component`, `default_*` for the rest |
| Files shipped verbatim | `package/<name>/<path as installed>`, copied by `install` |
| What a system installs | `profile/<profile>.sh`: flat `lfs_system_install X` (+ `lfs_install_package X#dev` for build-time files), in dependency order, the options of a package at its call site, and the kernel, `( capabilities="<capability>..."; lfs_system_install linux )`, among the packages |
| Helpers of one profile | in its file, for its own use: no package uses them (see Encapsulation) |
| Helpers several recipes share | `lib/<topic>.sh`, sourced in `lfs` (`lib/meson.sh`), or `lib/<category>.sh` for a package category, loaded for that category's recipes alone; recipe-facing names are plain (`meson_cross_file`, `move_to_dev_component`), framework functions are `lfs_*` (`lfs_tools_install`, `lfs_system_install`) |
| Kernel options every system needs | `package/linux/{base,<platform>,<arch>}.config`, each with its reason |
| Kernel options that are optional | `package/linux/<capability>.config`, each with its reason, named in the `capabilities` of the profiles that rely on it, and its part for an architecture, `package/linux/<capability>.<arch>.config`, or for a platform, `package/linux/<capability>.<platform>.config` |
| A change to an upstream source file (a device tree included) | a patch in `package/<name>/`, applied by `apply_patch` in `prepare`; a recipe never edits a source file with `sed` or `cat >>`. The Pi's device tree is `package/linux/<board>.patch`, which appends override nodes (later definitions win) |
| Static users and groups | `package/systemd/etc/{passwd,group,shadow}`, shipped by the init |
| The text of a licence that SPDX does not list | `package/<package>/LicenseRef-<name>.txt`: the source's own licence file, verbatim |

A profile is a whole system: the packages it holds, the init system and the kernel among them, as a
flat list in the order they are installed, with the options of each package at its call site. Its
name, `<platform>[-<name>]`, starts with the platform it runs on, and is the key of everything built
for it: `archive/<profile>/`, `install/<profile>`, `work/<profile>/sysroot`, `source/<profile>` and
the image. A profile installs in a subshell, after the toolchain. It sets no kernel option itself. A
kernel need is a capability, an option of the linux package: the profile names in the
`capabilities` option every capability it relies on, in alphabetical order, as capabilities do not
build on each other. Every profile installs the kernel, which `lfs` then copies, with the platform's device tree,
to `work/boot/<profile>`. Profiles share nothing but the build tools: a package that two profiles
install is built under each one's key, and the profiles of one platform build their toolchains
apart. Build-machine tools that a system build needs (swig, the Rust seed, native Python modules)
are installed into `TOOL_DIR` from the profile with `lfs_tools_install <package>`, archived
`*-tools-*` under the profile's key, never shipped. The tools that `lfs tools` builds are archived
under the key `tools` instead, and every system shares them, so their recipes use nothing of the
platform (`target_arch`, `kernel_arch` and the like are the platform's). A tool of a profile may:
`rust` does. Its files in `TOOL_DIR` are then the platform's, and two systems with such a tool
cannot be built at once.


Writing Recipes
---------------

Read two recipes like yours before starting: copy idioms, not ideas.

* Use the upstream's own targets and options (`headers_install`, meson options, `make install`)
  over re-implementing them; add the missing tool rather than a workaround.
* Link dynamically; static only where dynamic complicates things (gcc's in-tree gmp, mpfr and mpc).
* A feature a recipe lets the caller switch (`gpgsm`, `libgomp`, `python`) is off unless the caller
  turns it on: the recipe says `: ${gpgsm:=no}`, and a profile or `lib/tools.sh` sets `=yes` for
  the features it uses and `=no` for none. Options that take a value or a place (`hashes`, `bindir`)
  have no such default, and neither has one that is no feature (`stripping`, `ssldirs`).
* No documentation: no man (unless `man=yes`), info (unless `info=yes`), doc, locale or NLS files; the
  install calls `move_to_docs_component`. No empty directories in a system, except mount points. Real hardware
  comes first: the Pi's boot partition is firmware, `config.txt`, `cmdline.txt` and a flat device
  tree blob.
* Pin everything: `package_source_hash=sha256:<hex>` of the tarball, checked against the upstream's
  digest or PyPI's JSON API; patches via `patch_source URL sha256:...`.
* `package_license` is in SPDX for every recipe, from the real LICENSE files, bundled code
  included (Rust crates too).
* A file that another package installs is changed in that package's install (`system-files` is
  merged first, and the last file wins).
* Every program of a system has its interpreter in it: a script's shell (the systems have `dash`,
  not `bash`), an executable's dynamic linker. `make <profile>-system` runs `./lfs check`, which
  names those that lack it (`ldd` is a bash script); `./lfs check <package>` examines one package.
  Move such a program to the `dev` component, or leave it out.


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
* The `sysctl.d` file `50-default.conf` is rewritten in `package/systemd.sh`.
* A new service leaves `is-system-running` at `running`, `--failed` empty, and nothing new at
  warning level.


Kernel
------

The kernel is configured from `allnoconfig`, layers and capabilities. Write down every option relied on, even
the ones that default to y, and the parents that gate a menu (`USB_SUPPORT`, `NET`,
`NETWORK_FILESYSTEMS`, `NETDEVICES`: each bit once). Find dependencies in the Kconfig, which
`tar --include` extracts from the tarball, and verify the resolved `.config`, never the files of `package/linux/`.

Pi facts:

* The USB power domain needs `CONFIG_PM` and `RASPBERRYPI_POWER`, else dwc2 probes ten seconds
  late.
* `KUSER_HELPERS` is required by libatomic, which OpenSSL's libraries link on ARMv6: an eager
  `dlopen` of libcrypto faults without it.
* `HW_RANDOM_BCM2835` and `COMPAT_32BIT_TIME` are set.
* DMA stays off, for the regression of the bcm2835-dma driver in 6.18.
* virt takes RNG (virtio-rng) and its console (`hvc0`) from `virt.config`, and its USB host controller
  (xHCI) from `usb.virt.config`.


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
  `TOOL_DIR` Python against the target's sysconfigdata (`lib/python.sh`: `python_wheel` and
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
3. The system boots in QEMU: the standard checks are clean, and the change is exercised with
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
