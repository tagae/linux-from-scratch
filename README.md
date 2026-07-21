Linux From Scratch
==================

Build [Linux From Scratch with systemd](https://www.linuxfromscratch.org/lfs/view/systemd/),
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

Built images contain a minimal Linux system that boots cleanly and is accessible through the serial
console. Two init flavors are available: **systemd** (the default) and a **BusyBox-only** system
with BusyBox as PID 1. Everything is cross-compiled from source inside Docker.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.


Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU virtual machine         | host          |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |

`virt` is the default platform. (`pi5` is best-effort — QEMU has no Pi 5 machine model yet.)


Quick Start
-----------

Build the whole chain for the default system — cross-toolchain, packages, disk image — then boot it
in QEMU, log in as root, and power off, asserting a clean exit:

```shell
make test
```

Everything runs in Docker and the first build is slow. Target another platform by suffixing its
name; the whole chain rebuilds for it:

```shell
make test-pi0
make test-pi4
```

Build the BusyBox-init flavor instead of systemd with the `busybox-` prefix:

```shell
make busybox-test         # virt
make busybox-test-pi0
```

Each platform/flavor lives in its own install tree and image, so they never clobber one another, and
the cross-toolchain is a shared volume — building one platform only ever adds to it.


Building and booting by stage
-----------------------------

`test` runs the full chain and boots headless; the stages can also be run on their own. Each defaults
to `virt`/systemd; suffix a platform and/or prefix `busybox-`:

```shell
make tools      # cross-toolchain + temporary build tools
make system     # build every package into the target install tree
make image      # produce a bootable disk image
make qemu       # boot the image in QEMU (interactive serial console)
```

For example `make system-pi0`, `make busybox-system-pi4`, `make qemu-pi0`, `make busybox-qemu`.
Per-platform images are the file targets `image/<platform>.img` / `image/busybox-<platform>.img`
(e.g. `make image/pi0.img`), and are built automatically by the matching `qemu`/`test` goal.

`make distclean` tears down the Docker volumes, `work/`, and `image/` for a clean rebuild.


Testing
-------

`make test` (and `make <platform>-test` / `make busybox-test[-<platform>]`) boots the image in QEMU,
logs in as root, runs `poweroff`, and verifies that QEMU exits cleanly. It drives the `./test` expect
script, which takes the platform and init flavor as arguments (`./test pi0 busybox`) and reads the
kernel and disk image the build staged out of the Docker volumes.
