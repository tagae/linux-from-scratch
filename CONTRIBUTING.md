Contributing To This Project
============================

Overview
--------

* `lfs`: CLI frontend
* `lib/`: framework implementation; contains the `lfs` subcommands
* `platform/`: platform definitions
* `profile/`: system recipes, the files of each system (`profile/<profile>/`), and the documentation
  of a profile (`profile/<profile>.md`)
* `package/`: package recipes
* `download/`: fetched artefacts
* `work/`: per profile (e.g., `work/virt`) and for the tools (`work/tools`): unpacked sources
  (`source/`), build dirs, the system tree (`system/`) and the sysroot of the cross toolchain
* `tools/`: built tools and cross toolchain for each platform
* `archive/`: package tarballs and SHA-256 digests
* `image/`:  built disk images
* `bin/`: project maintenance commands
* `check/`: quality assurance utilities
* `Makefile`: build rules
* `Dockerfile.{bootstrap,scratch,dev}`: build and dev containers for reproducibility


Building the Toolchain
----------------------

### Bootstrap

An initial (throwaway) toolchain is built through the host's tools.

The following command builds a cross-compiler plus a native set of temporary tools (bash,
coreutils, make, wget, ...)  into the `tools` directory.

```shell
./lfs tools bootstrap
```

### Scratch

A full self-hosted toolchain is built using the bootstrapped toolchain built in the previous stage.

The following command adds build-host-only tooling (Python, meson/ninja, kmod, btrfs-progs, ...)
into the `tools` directory:

```shell
./lfs tools build
```

With this, the tools are fully functional and can be used to build packages.


Building the System
-------------------

The following command builds the system for a given profile, into `work/$LFS_PROFILE/system`, the system tree:

```shell
./lfs system build
```

It first builds a cross toolchain for the profile's platform: `binutils`, a first `gcc`, the Linux
API headers and the C library, `glibc` or `musl`, then the full cross `gcc`. The profile asks for
it in its first statement, `lfs_system_toolchain glibc|musl`, which gives the system's C library.
Everything else comes from the profile definition at `profile/$LFS_PROFILE.sh`, compiled with that
toolchain. This includes the kernel (`linux` with a given set of capabilities), init (`systemd` or
`busybox`), and further packages. Once the profile has run, the build copies the files of
`profile/$LFS_PROFILE/` into the system tree.


Images
------

The following command makes a disk image from the system tree at `work/$LFS_PROFILE/system`, as
populated by `./lfs system build`:

```shell
./lfs image build
```

Images observe the [Linux Filesystem Hierarchy Standard].

Images are accompanied by an SBOM document (`<image>.spdx.json`) in SPDX 2.3 format.
Scanners can use this document to signal vulnerabilities.

They also come with a manifest of the files of each file system, `<image>.root.txt` and, for
the Pi layout, `<image>.boot.txt`: one path per line, absolute from the file system's root,
sorted by byte.

It is possible to write the system directly to a device:

```shell
sudo LFS_ERASE=/dev/sdb ./lfs image build /dev/sdb
```

`LFS_ERASE` is required to ensure the user does intend to obliterate any data that might be present
on the device.


Emulating
---------

The following command boots the built image:

`./lfs qemu`

A qcow2 overlay (`<image>.qcow2`) receives the writes, so that the image remains untouched.


Package Model
-------------

Each `package/<name>.sh` runs in a fresh subshell that predefines the hooks
`fetch`/`prepare`/`build`/`install`/`archive`/`unarchive` with sane defaults.

A package's name is the path of its recipe under `package/`, without the `.sh`. The Python
libraries live in `package/python/` and are named `python/<name>`, after their PyPI project without
any `python-` prefix, e.g. `lfs_system_install python/click`.

The directory of a package's name is its category (`python` for `python/click`, `.` for `bash`).
The framework puts everything of the package in the category's directory of `download/`,
`work/<key>/source/`, `work/<key>/` and `archive/<key>/`: its downloads and patches, its unpacked
sources, its build, stage and component directories, and its archives. Packages of different
categories therefore never share a path, so `python/foo` and `foo` can coexist.

A category can have helpers for its recipes in `lib/<category>.sh` (`lib/python.sh` for `python`),
which the framework loads for the recipes of that category.

A recipe downloads in `fetch`, and unpacks with `unpack`: `./lfs fetch` runs the `fetch` of every
recipe for the profile's platform with `unpack` doing nothing, and `make fetch` runs it for each
profile, so that CI downloads every source once, before any build. What a recipe downloads anywhere
else (the crates of `cryptography`, in `prepare`) is downloaded by each build.

A package may list other packages in `package_fetch_dependencies`, whose sources it needs to build.
The framework fetches them before building the package, and exposes their locations as
`<dependency>_source_dir` (`libgpg_error_source_dir` for `libgpg-error`).

The `package_license` list the package's license in [SPDX format][SPDX License List]. A licence that
the list does not have is a `LicenseRef-<name>`, whose text is the file
`package/<package>/LicenseRef-<name>.txt`, which the SBOM carries and `check/lint` looks for.

A package's install can set its development files (headers, static libraries, pkg-config files...)
aside for its `dev` component with `move_to_dev_component`, which is installed only where
wanted.

Programs and libraries are stripped as they are linked.


Conventions
-----------

All shell code should be POSIX compliant.

### External API

Shell variables are part of the **external API** if they are used to parameterise `lfs`. They are
the only variables that `lfs` passes on to builds, along with `PATH` and `TMPDIR`.

External API variables have uppercase names, prefixed with `LFS_` so that none clashes with a
variable of the caller's (e.g., `LFS_PROFILE`, `LFS_TIMEZONE`). `PATH` and
`TMPDIR` are the platform's own, and keep their names. `lfs` ignores every variable that it does not
name.

After `tools bootstrap`, which builds the first toolsset, `PATH` holds the tools' directories only:
nothing of the host's (a program, a config script, an interpreter) finds its way into a build.

### Internal API

Shell variables are part of the **internal API** if they are used by functions, and are not part of
the external API (e,g. `package_version`, `prefix`).

Internal API variables have lowercase names.

Internal API variables must not be exported.

### Encapsulation

A package recipe owns the functions it defines. Other package recipes or profiles should not call
those functions, as that would make a package depend on the implementation of another.  Packages
rely only on the framework (`lib/`).

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

### Versions and Commits

The project's versions follow SemVer, and a release is an annotated git tag `MAJOR.MINOR.PATCH`,
with no prefix, from the baseline `0.0.0`. `bin/version` prints the version of a tree: the tag's when
the tree is clean and on the commit of the most recent tag, and otherwise a pre-release of the next
version, named by the abbreviated hash of the top commit, as short as git finds it unambiguous
(`0.2.0-abc1234`), and ended by `-dirty` when the tree differs from its commit. A hash of digits alone
that starts with 0, which SemVer does not allow in a number, takes an `r`, for revision
(`0.2.0-r0123456`). The next version is the tag's, raised by the summary lines of the commits since
it: an `Add` after `0.1.0` makes `0.2.0`, and a `Fix` on top of it changes the hash, not the version.
(Build metadata, `+hash`, would not do: SemVer ignores it when it compares versions.) `bin/release`
tags the next version (`--dry-run` says which first), and `git push github X.Y.Z` publishes the tag.
The Makefile gives an image its release (`LFS_RELEASE`, the output of `bin/version`: os-release's
`VERSION`, the SBOM). It goes into no archive, as every revision shares them.

Commit messages follow [docs/commit-messages.md](docs/commit-messages.md). The first word of the
summary line tells what bump the commit makes:

| First word                                                                  | Bumps         |
|-----------------------------------------------------------------------------|---------------|
| `Drop`, `Stop`, `Major`                                                     | the major one |
| `Add`, `Start`, `Minor`                                                     | the minor one |
| `Fix`, `Optimize`, `Refactor`, `Patch`                                      | the patch     |
| any other, such as `Bump`, `Make`, `Document`, `Reword`, `Remove` or `Move` | nothing       |

The highest bump of the commits since the last tag applies, and sets the parts after it to 0. With
only commits that bump nothing since the last tag, `bin/version` shows a pre-release of the next
patch (a pre-release of the tag would sort before it), and `bin/release` has nothing to tag. Merges,
fixups and squashes bump nothing. A trailer such as `BREAKING CHANGE:` means nothing: a change that
breaks the interface says so with its first word. `Drop` and `Stop` are for what users may rely on,
which they remove or end; `Major` is for any other change that breaks the interface (a feature that
changes in a way that breaks its users). `Remove` is for what nothing relies on.

The interface is what users and profiles rely on: the make targets and their defaults, the `lfs`
commands and environment, the formats of `profile/`, `platform/` and the options of recipes, and the
layout of an image and of its SBOM. What an image holds is not the interface: updating a package
that has vulnerabilities is a `Fix`, and any other update a `Bump`, which bumps nothing.

`check/commit-messages` (`make commit-lint`, which CI runs) checks the messages since the last tag,
or all of them when there is none: the summary line, a blank line after it and the width of the
body. `git config core.hooksPath check/hooks` makes git refuse a commit whose message fails it, and
`git config commit.template docs/commit-template.txt` gives the editor the template of a message.

### Documentation

Documentation never mentions an actual commit hash, which a rewrite of the history changes: it names
a release by its tag, a commit by its summary line and a state of the tree by its date. A made-up
hash, as in an example of a version, is fine.

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
| What a system installs | `profile/<profile>.sh`: `lfs_system_toolchain <libc>`, then flat `lfs_system_install X` (+ `lfs_sysroot_install X#dev` for build-time files), in dependency order, the options of a package at its call site, and the kernel, `( capabilities="<capability>..."; lfs_system_install linux )`, among the packages |
| Helpers of one profile | in its file, for its own use: no package uses them (see Encapsulation) |
| Helpers several recipes share | `lib/<topic>.sh`, sourced in `lfs` (`lib/meson.sh`), or `lib/<category>.sh` for a package category, loaded for that category's recipes alone; recipe-facing names are plain (`meson_cross_file`, `move_to_dev_component`), framework functions are `lfs_*`, and those that install a package are `lfs_<destination>_install` (`lfs_system_install`, `lfs_sysroot_install`, `lfs_tools_install`, `lfs_toolchain_install`) |
| Kernel options every system needs | `package/linux/{base,<platform>,<arch>}.config`, each with its reason |
| Kernel options that are optional | `package/linux/<capability>.config`, each with its reason, named in the `capabilities` of the profiles that rely on it, and its part for an architecture, `package/linux/<capability>.<arch>.config`, or for a platform, `package/linux/<capability>.<platform>.config` |
| Applets of BusyBox | `package/busybox/<category>.config`, named in the `applets` of the profiles that rely on it: the category's applets that the kernels serve and a bare system has a use for, and their options, each category with its reasons; `base.config` has the options that every system gets |
| A change to an upstream source file (a device tree included) | a patch in `package/<name>/`, applied by `apply_patch` in `prepare`; a recipe never edits a source file with `sed` or `cat >>`. The Pi's device tree is `package/linux/<board>.patch`, which appends override nodes (later definitions win) |
| Static users and groups | `package/<init>/etc/{passwd,group,shadow}` (`systemd`, `busybox`), shipped by the init, with root locked (`!`) and `/bin/sh` |
| The files that give a system its look and its policy, and what only it has (issue, motd, the shell profile, root's dotfiles, the udev rules and systemd drop-ins that name its regular account or its devices, a script of its own with its units) | `profile/<profile>/<path as installed>`, which the build copies after the profile's packages, with `$LFS_USER` (the regular account's name) replaced and nothing else: a path that a package installs is an error. Two profiles that want one file each have a copy of it, as profiles share nothing |
| root's password and shell | `( root_shell=/bin/bash; lfs_system_set_root )` in the profile, after the packages: it has no password unless `LFS_ROOT_PASSWORD` sets one, which belongs to the build, so no package ships it |
| The regular account of a system | `( user_shell=/bin/bash; lfs_system_add_user )` in the profile, after the packages: its name is `LFS_USER`, and it has no password unless `LFS_PASSWORD` sets one; both belong to the build, so no package ships the account |
| The text of a licence that SPDX does not list | `package/<package>/LicenseRef-<name>.txt`: the source's own licence file, verbatim |

A profile is a whole system: the packages it holds, the init system and the kernel among them, as a
flat list in the order they are installed, with the options of each package at its call site. Its
name, `<platform>[-<name>]`, starts with the platform it runs on, and is the key of everything built
for it: `archive/<profile>/`, `work/<profile>/system`, `work/<profile>/sysroot`,
`work/<profile>/source` and the image. A profile installs in a subshell, and starts with its toolchain,
`lfs_system_toolchain glibc|musl`, whose C library is the system's: the library gives the ABI of the
target triplet (`aarch64-scratch-linux-musl`), after which the platform's EABI follows (`eabihf`,
for the pi0). It sets no kernel option itself. A
kernel need is a capability, an option of the linux package: the profile names in the
`capabilities` option every capability it relies on, in alphabetical order, as capabilities do not
build on each other. Every profile installs the kernel, which `lfs` then copies, with the platform's device tree,
to `work/boot/<profile>`. Profiles share nothing but the build tools: a package that two profiles
install is built under each one's key, and the profiles of one platform build their toolchains
apart. Build-machine tools that a system build needs (swig, the Rust seed, native Python modules)
are installed into `LFS_TOOL_DIR` from the profile with `lfs_tools_install <package>`, archived
`*-tools-*` under the profile's key, never shipped. The tools that `lfs tools` builds are archived
under the key `tools` instead, and every system shares them, so their recipes use nothing of the
platform (`target_arch`, `kernel_arch` and the like are the platform's). A tool of a profile may:
`rust` does. Its files in `LFS_TOOL_DIR` are then the platform's, and two systems with such a tool
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
  digest or PyPI's JSON API; patches are kept in the repository.
* `package_license` is in SPDX for every recipe, from the real LICENSE files, bundled code
  included (Rust crates too).
* A file that another package installs is changed in that package's install (`system-files` is
  merged first, and the last file wins). A profile's files come last, and never replace one.
* Every program of a system has its interpreter in it: a script's shell (`/bin/sh` is `dash`, or
  `ash` where BusyBox is the userland, and a system that has `bash` for its users' sake has no
  script of its own that runs in it), an executable's dynamic linker (`ldd` is a bash script). Move
  such a program to the `dev` component, or leave it out.


systemd
-------

* No presets run. A unit is enabled as `systemctl enable` does it: the recipe makes the symlink
  under `/etc/systemd/system/<target>.wants/`, with an absolute target in
  `/usr/lib/systemd/system`; a symlink under `/usr/lib` reads as "disabled" to `is-enabled`. A
  profile ships regular files only, so it enables a unit with a drop-in that wants it
  (`profile/<profile>/etc/systemd/system/<target>.target.d/<unit>.conf`, with `Wants=`).
* The image bakes a machine ID (`lib/image.sh`): the first boot is ordinary, and a first-boot
  `preset-all` would only warn about generated units. Images are per build, not per card.
* D-Bus is there (`dbus`, started by its socket), and there is no PAM, polkit or logind. Without
  polkit, only root changes anything through the bus (`poweroff`, `systemctl restart`); other users
  read (`systemctl status`).
* Passwd is static: services run as root unless the user exists in the static files. Where
  upstream's unit needs a dedicated user or `PrivateUsers=full`, ship a small unit of our own
  (`pcscd.service`). Prefer socket activation (`--auto-exit`).
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
  `LFS_TOOL_DIR` Python against the target's sysconfigdata (`lib/python.sh`: `python_wheel` and
  `python_install_wheel` for a build backend, `python_install_modules` for pure Python,
  `python_site_packages`; templates `package/python/cffi.sh` and `package/python/pycparser.sh`).
  Recipes never mention `python_version`, which the framework sets. Bytecode is precompiled
  unchecked-hash so that the Pi never writes `__pycache__`; no pip, and no dist-info unless
  metadata is read at run time. The default `package_source_dir` is right unless the sdist's
  directory is spelled differently from the name (`more_itertools-...`): then the recipe sets it,
  with `python/` in it.
* Rust: the seed is in `LFS_TOOL_DIR` (`package/rust.sh`, `lfs_tools_install rust`); the triple is
  `$target_arch-unknown-$target_kernel-$target_abi`; crates are fetched at fetch time and built
  `--locked --offline`; `--remap-path-prefix` keeps build paths out of panics; binaries are
  stripped.
* ARMv6: no `-march` or `-mcpu` overrides from a build system's guesses (`readelf -A` shows no
  v7-only instructions); 32-bit atomics are inline, 64-bit ones go through libatomic (shipped by
  `gcc#runtime`).
* An ELF file that carries a build-machine path (RPATH, debug sections, panic strings) is a defect.

### Platforms with the Build Machine's Own Triple

On virt and arm64, built on an aarch64 Mac, with glibc, the triple is `aarch64-unknown-linux-gnu`, the
build machine's, though the compiler is the cross `aarch64-scratch-linux-gnu-gcc`: tools that
compare triples see a native build. For `cryptography`:

* cargo has one linker setting per triple, shared by build scripts and proc-macros (which run on the
  build machine; `rust.sh`'s `cargo` wrapper points them at the tools' compiler) and by the
  platform's code. With equal triples the cross linker is silently replaced, and the extension
  links against the tools' glibc with its RPATH. The cross linker goes to the single compilation
  that links the platform's code: `cargo rustc ... --lib -- -C linker=$host-gcc`.
* The `cc` crate reads `CC_<triple_with_underscores>`, then `HOST_CC` if the triples are equal, else
  `TARGET_CC`, then `CC`: set `CC_<triple>` and `AR_<triple>`.
* pyo3 detects cross builds by comparing triples: set `PYO3_CROSS=1` with `PYO3_CROSS_LIB_DIR`.
* The `LFS_TOOL_DIR` Python and the platform's share a multiarch name: select the sysconfigdata by
  name and by path (`python_wheel` sets `_PYTHON_SYSCONFIGDATA_NAME` and `_PATH`).
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


[Linux Filesystem Hierarchy Standard]: https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html
[SPDX License List]: https://spdx.org/licenses/
