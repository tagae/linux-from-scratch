Contributing
============

What this is
-------------

A from-scratch build system that cross-compiles a minimal, bootable Linux —
[systemd](https://www.linuxfromscratch.org/lfs/view/systemd/) or BusyBox
init, with a BusyBox or GNU userland — for QEMU `virt` and Raspberry Pi
targets (pi0/pi4/pi5), from source. Everything the target runs is built
by this project's own recipes.


Quick start
-----------

```shell
make tools    # cross-toolchain + temporary build tools (slow; once per platform)
make system   # build every package into the target install tree
make image    # produce a bootable disk image
make qemu     # boot it in QEMU
make test     # tools + system + image + boot, log in, poweroff, assert clean exit
```

All default to `PLATFORM=virt`, `USERLAND=systemd-busybox`, empty `CAPS`;
everything above runs inside Docker. For another platform use
`<verb>-<platform>` (e.g. `make system-pi0`); select the flavor and
capability set with variables (`make test USERLAND=busybox`, `make test
CAPS="network 9p"`). `make distclean` tears down the Docker volumes,
`work/` and `image/`, for a clean rebuild.


How a build flows
------------------

Two Docker images, two phases:

1. **`bootstrap`** (Debian, `Dockerfile.bootstrap`) — `./lfs tools
   bootstrap` builds a cross-compiler plus a native, relocatable set of
   temporary tools (bash, coreutils, make, wget, ...) into the `tools`
   volume.
2. **`scratch`** (`FROM scratch`, `Dockerfile.scratch`) — self-hosted
   using only what `bootstrap` staged. `./lfs tools build` adds
   build-host-only tooling (Python, meson/ninja, kmod, btrfs-progs, ...);
   `./lfs system build` cross-compiles the target system into
   `install/$SYSTEM_KEY`; `./lfs image build` formats a disk image from
   that tree.

`./lfs qemu` runs on the host, not in a container (QEMU needs to see the
built kernel/image); `docker-compose.yaml` bind-mounts `work/boot` and
`image/` out for that reason.

`lfs` is the CLI frontend (`tools`, `system`, `install`, `unarchive`,
`image`, `qemu`, `fetch`); `lib/*.sh` implements each command;
`package/*.sh` are the build recipes. `-p PLATFORM` selects the target
(`lib/platform/$PLATFORM.sh`, default `virt`); `USERLAND` selects the
userland umbrella — the complete userspace composition, init system
included (`package/bootable-$USERLAND.sh`: `systemd-busybox`,
`systemd-coreutils`, `busybox`); `CAPS` opts into capabilities
(`network`, `9p`, `usb`, `loop`, `amnesia` — each names a kernel config
fragment `package/linux/<cap>.config`, plus optional `*-config` packages
and QEMU devices; code tests membership with `has_cap`, `lib/base.sh`).
`SYSTEM_KEY` — always `$USERLAND-$PLATFORM`, plus a sorted `+<cap>` suffix
per capability — keys the install tree, stamps, boot files, archives and
image, so switching `PLATFORM`/`USERLAND`/`CAPS` never clobbers another
combination's build.


The package model
------------------

Each `package/<name>.sh` runs in a fresh subshell (`_source` in
`lib/package.sh`) that predefines the hooks `fetch`/`prepare`/`build`/
`install`/`depends` with sane defaults. A script sets a few
`: ${var:=default}` knobs and overrides only what it needs:

```sh
: ${package_version:=5.3}
: ${package_source:=https://ftp.gnu.org/gnu/bash/bash-$package_version.tar.gz}
: ${package_source_hash:=sha256:...}

prepare() { $package_source_dir/configure ${host:+--host=$host} ...; }
build()   { make; }
install() { make install DESTDIR=$package_install_dir; }
```

See `package/bash.sh`/`make.sh` for a minimal example, `util-linux.sh`
for heavy knob use. Every knob (`host`, `prefix`, `nls`, ...) is a plain
variable, defaulted with `:=` and overridden by the caller before
`require`/`install`, e.g. `nls=no install m4`.

Two verbs drive everything:
- **`install <pkg>...`** — the `lfs install` command: establishes the
  target build scenario (`host=$target`, `package_install_dir=
  $INSTALL_DIR/$SYSTEM_KEY`, ...) unless already set, then calls
  `require`. Not to be confused with the per-package `install()` *hook*
  above (same name, different layer: this sets up the scenario and
  installs a set of packages; the hook is one package's own install step).
- **`require <pkg>...`** — fetch/prepare/build/install one or more
  packages, each step stamped so reruns skip what's already done. What
  umbrella `depends()` hooks call too.

**Umbrellas** are meta-packages: `package_meta=yes` plus a `depends()`
that just `require`s members with their knobs, nothing else. `bootable-
$USERLAND` (`bootable-systemd-busybox.sh`/`bootable-systemd-coreutils.sh`/
`bootable-busybox.sh`) is the package list for a bootable system;
`build_system` (`lib/system.sh`) is just `install bootable-$USERLAND` plus
staging the kernel for `./lfs qemu`. `ncdu.sh` shows the same `depends()`
mechanism used by an ordinary leaf package to pull in a build-only
dependency (wide ncurses).

`target_sysroot_cc` is an opt-in a package's `prepare()` calls when it
links a library another package already installed into the target tree
(util-linux, the gnupg family, ncdu) — it points `CC` at the
cross-compiler with `--sysroot=$INSTALL_DIR/$SYSTEM_KEY` so `-lfoo`
resolves against the target tree, not the toolchain's default sysroot.

The package/umbrella model and the USERLAND/SYSTEM_KEY flavor split are
documented in `lib/package.sh`'s and `lfs`'s own comments.


Make targets
------------

```
<verb>              == <verb>-virt      (default platform)
<verb>-<platform>                       (any platform; USERLAND/CAPS via variables)
```

`<verb>` is `system`/`image`/`qemu`/`test`, plus `reinstall-tools`/
`reinstall-system` (and their keyed `reinstall-*-<platform>` forms). One
rule set, parameterized by `USERLAND` and `CAPS` — no per-flavor or
per-capability targets. `tools`/`tools-<platform>` is shared across
flavors. Image targets are real files (`image/$SYSTEM_KEY.img`), not
phony names. `make check`/`check-probes`/`e2e-test` run the regression
tiers (see `tests/README.md`).


Conventions & gotchas
----------------------

- POSIX `sh` only in `lib/`/`package/`, no bashisms (bash is just the
  shell the images happen to run). ash/dash's `A | B` does not fail the
  pipeline if `A` fails — no `pipefail` — so such failures are mostly
  left unhandled rather than worked around.
- No documentation is built (`--disable-doc`, `manpages=no`, ...): keep
  images minimal.
- Sources and patches are hash-pinned (`package_source_hash`,
  `"algo:hexdigest"`, e.g. `sha256:...`) and always fetched over TLS
  verified against `$SSL_CERT_FILE` — `fetch_url` (`lib/base.sh`) refuses
  to download without a CA bundle, and the scratch phase trusts the
  project's own from-scratch bundle, never a copy of Debian's.
- A package that links a library already installed into the target tree
  must opt into `target_sysroot_cc` or it silently links the wrong glibc.
- `SYSTEM_KEY` namespacing makes switching `PLATFORM`/`USERLAND` safe by
  construction — don't hand-reuse another flavor's `package_variant`/
  `package_install_dir`.


Where things live
------------------

* `lfs` — CLI frontend.
* `lib/` — `base.sh`/`package.sh` (core framework), `tools.sh`/
  `system.sh`/`image.sh`/`qemu.sh` (the phases and the boot command),
  `platform/*.sh` (per-target defs).
* `package/` — one recipe per package; `linux/` holds the per-platform
  and per-capability kernel config fragments.
* `download/`, `source/`, `work/`, `tools/`, `install/`, `archive/`,
  `image/` — build state (fetched archives, unpacked sources, stamps/
  build dirs, the toolchain, the target install tree, per-package
  tarballs + their `ORDER` manifest, finished disk images); the
  Docker-volume-backed ones are declared in `docker-compose.yaml`.
* `Dockerfile.bootstrap` / `Dockerfile.scratch` — the two build containers.
* `test` — the boot-matrix expect script `make test`/`test-<platform>` drive.
* `tests/` — the staged regression suite (`make check`/`check-probes`/
  `e2e-test`).


Pointers
--------

https://www.raspberrypi.com/documentation/computers/processors.html
http://www.dettus.net/detLFS/
https://www.linux-magazine.com/Issues/2021/245/detLFS
https://blog.jgosmann.de/posts/2021/02/07/a-guide-to-crosscompiling-applications/

Architecture records: `docs/design/` (package framework, packaging,
build phases, capabilities, kernel config, trust, self-hosting, the
GnuPG appliance). Open cleanups: `SIMPLIFICATIONS.md`.
