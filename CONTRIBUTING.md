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

The `package/*.sh` files are the build recipes.


Building the Toolchain
----------------------

1. **`bootstrap`** Relies on the host for the initial set of tools used to bootstrap our own. The
   `./lfs tools bootstrap` command builds a cross-compiler plus a native, relocatable set of
   temporary tools (bash, coreutils, make, wget, ...) into the `tools` directory.
2. **`scratch`** Self-hosted using only what `bootstrap` staged. The `./lfs tools build` command
   adds build-host-only tooling (Python, meson/ninja, kmod, btrfs-progs, ...) into the `tools`
   directory.


Building the System
-------------------

* The `./lfs system build` command cross-compiles the target system into `install/$SYSTEM_KEY`.
* The `./lfs image build` command formats a disk image from a built system tree.
* The `./lfs qemu` command runs the built image.

No documentation is built (man pages, info pages, etc.). This might change in the future, making it
optional (opt in or opt out: to be decided).


Package Model
-------------

Each `package/<name>.sh` runs in a fresh subshell that predefines the hooks
`fetch`/`prepare`/`build`/ `install`/`depends` with sane defaults.

See `package/`{`bash.sh`,`make.sh`} for a minimal example, `util-linux.sh` for heavy knob use.


Conventions
-----------

- All shell code should be POSIX compliant.
- Non-exported variables should be in lowercase (e.g., `package_version`)..
- Exported variables should be in uppercase (e.g., `PATH`).


Gotchas
-------

- Mind that ash/dash's `A | B` does not fail the pipeline if `A` fails.


Pointers
--------

- https://www.raspberrypi.com/documentation/computers/processors.html
- http://www.dettus.net/detLFS/
- https://www.linux-magazine.com/Issues/2021/245/detLFS
- https://blog.jgosmann.de/posts/2021/02/07/a-guide-to-crosscompiling-applications/
