Contributing
============

Overview
--------

* `lfs`: CLI frontend
* `lib/`: LFS framework
* `package/`: package recipes
* `download/`: fetched archives
* `source/`: unpacked sources
* `work/`: build dirs
* `tools/`: toolchains
* `install/`: target install trees
* `archive/`: package tarballs
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
`./lfs tools build
```

With this the tools are fully functional and can be used to build packages.


Building the System
-------------------

* The `./lfs system build` command cross-compiles the target system into `install/$SYSTEM_KEY`.
* The `./lfs image build` command formats a disk image from a built system tree.
* The `./lfs qemu` command runs the built image.


Package Model
-------------

Each `package/<name>.sh` runs in a fresh subshell that predefines the hooks
`fetch`/`prepare`/`build`/ `install`/`depends` with sane defaults.

A package may list other packages in `package_fetch_dependencies`, whose sources it needs to build.
The framework fetches them before building the package, and exposes their locations as
`<dependency>_source_dir`.


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
