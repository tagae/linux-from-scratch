Contributing
============

Overview
--------

* `lfs`: CLI frontend
* `lib/`: LFS framework
* `package/`: package recipes
* `download/`: fetched archives
* `source/`: unpacked sources
* `work/`: build dirs, and the sysroots of the cross toolchains
* `tools/`: toolchains
* `install/`: target install trees, one per system key
* `archive/`: package tarballs, each with its SHA-256 digest
* `image/`:  disk images
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
is then compiled with that toolchain, followed by the kernel. Each package is installed both into
the system tree and into the toolchain's sysroot, `work/$SYSTEM_KEY/sysroot`, which also receives
what compiling against the packages needs: the Linux API headers and the packages' `dev`
components. The kernel is also copied to `work/boot/$SYSTEM_KEY`, where QEMU on the host finds it.

```shell
./lfs system build
```


Images
------

* The `./lfs image build` command formats a disk image from the install tree at
  `install/$SYSTEM_KEY`, as populated by `./lfs system build`. Given a block device instead of an
  image file, it formats the device and fills it the same way, with the root file system taking
  all of the space the boot partition leaves.
* The `./lfs qemu` command runs the built image.

An image or a device is opened through loop devices and mounts, so making one needs a privileged
container and root, e.g. `docker compose run --rm --user 0:0 scratch ./lfs image build`. Making a
system on a device erases it, so that takes `ERASE`, set to the same device, e.g.
`ERASE=/dev/sdb ./lfs image build /dev/sdb`. A device that anything has mounted or opened, in the
container or on the host, is refused (unmount a card from a desktop's automounter first). Outside
the scratch container, which has them, a host needs `btrfs-progs`, `dosfstools` and `fdisk` (for
`sfdisk`), besides the usual `util-linux` and `tar`.


Package Model
-------------

Each `package/<name>.sh` runs in a fresh subshell that predefines the hooks
`fetch`/`prepare`/`build`/`install`/`archive`/`unarchive` with sane defaults. `install` runs into
an empty stage, so an archive holds exactly what it installed. The default `archive` records the
archive's SHA-256 digest next to it, and the default `unarchive` installs an archive only if it
still matches.

A package may list other packages in `package_fetch_dependencies`, whose sources it needs to build.
The framework fetches them before building the package, and exposes their locations as
`<dependency>_source_dir`.

The `package_license` list the package's license in [SPDX format][SPDX License List].

A package's install can set files aside for its split components (see `lib/split.sh`): its
development files (headers, static libraries, pkg-config files...) for its `dev` component, its
documentation (man and info pages, `/usr/share/doc`) for its `docs` component, and, when built with
debugging information, that information for its `debug` component, leaving its programs and
libraries stripped. Split components are installed only where wanted: `dev` into build trees, while
`docs` and `debug` stay in their own archives (the debugging information belongs under
`/usr/lib/debug`), to unpack into a system by hand. The system carries readers for the `docs` components: `man` from mandoc,
which needs zlib, and `info` from texinfo, of which only the reader and `install-info` are built.


Conventions
-----------

All shell code should be POSIX compliant.

### External API

Shell variables are part of the **external API** if they are used to parameterise `lfs`.

External API variables have uppercase names (e.g., `PLATFORM`, `USERLAND`, `CAPS`)

External API variables might be exported in invocations of `lfs`, but are never exported internally
as part of internal logic.

### Internal API

Shell variables are part of the **internal API** if they are used by functions, and are not part of
the external API (e,g. `package_version`, `prefix`).

Internal API variables have lowercase names.

Internal API variables must not be exported.


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
