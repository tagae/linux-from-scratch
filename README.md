Linux From Scratch
==================

Build [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/systemd/)
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

Built images contain a minimal Linux system that boots cleanly and is accessible through the serial
console. Further opt-in **capabilities** can be layered on top of the base system, for example to
add networking support.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.

Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU virtual machine         | host          |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |

Userland Flavours
------------------

| Userland            | Init (PID 1) | Core utilities             |
|---------------------|--------------|----------------------------|
| `systemd-coreutils` | systemd      | GNU (coreutils, bash, …)   |
| `systemd-busybox`   | systemd      | BusyBox                    |
| `busybox`           | BusyBox      | BusyBox (static, no glibc) |

The `busybox` flavour is fully static, without `glibc`, so dynamically-linked optional packages
require a `systemd` flavour.

Capabilities
------------

| Capability | What it enables                                                     |
|------------|---------------------------------------------------------------------|
| `network`  | Networking: DHCP + DNS (systemd-networkd/-resolved)                 |
| `9p`       | Host file sharing: the project directory mounted over virtio-9p     |
| `usb`      | Removable USB storage (attach a stick with `USB_DISK=<img>`)        |
| `loop`     | Loop devices + partitioning tools, so a guest can build disk images |
| `amnesia`  | Read-only root: the boot medium never written                       |

Capabilities are off by default and combinable (`CAPS="network 9p"`); each combination gets its own
kernel, install tree and image. The `network`/`9p` QEMU device wiring is virt-only. Details in
`docs/design/capabilities.md`.

Quick Start
-----------

Build the whole chain for the default system, then boot it in QEMU, log in as root, and power off,
asserting a clean exit:

```shell
make test
```

Everything runs in Docker and the first build is slow. Target another platform by suffixing its
name; the whole chain rebuilds for it:

```shell
make pi0-test
make pi4-test
```

Select another userland flavor with the `USERLAND` variable, and opt into capabilities with `CAPS`:

```shell
make test USERLAND=busybox
make pi0-test USERLAND=systemd-coreutils
make test CAPS="network 9p"
```

Each platform/flavor/capability combination lives in its own install tree and image, so they never
clobber one another, and the cross-toolchain is a shared volume — building one platform only ever
adds to it.


Building and booting by stage
-----------------------------

`test` runs the full chain and boots headless; the stages can also be run on their own. Each defaults
to `virt`/`systemd-busybox`; suffix a platform and/or set the `USERLAND` variable:

```shell
make tools      # cross-toolchain + temporary build tools
make system     # build every package into the target install tree
make image      # produce a bootable disk image
make qemu       # boot the image in QEMU (interactive serial console)
```

For example `make pi0-system`, `make pi4-system USERLAND=busybox`, `make pi0-qemu`, `make qemu USERLAND=busybox`.
Images are the file targets `image/<userland>-<platform>[+<cap>...].img` (e.g.
`make image/systemd-busybox-pi0.img`; `make image CAPS=network` produces
`image/systemd-busybox-virt+network.img`), built automatically by the matching `qemu`/`test` goal.

`make distclean` tears down the Docker volumes, `work/`, and `image/` for a clean rebuild.


Testing
-------

`make test` (and `make <platform>-test`, with optional `USERLAND=`/`CAPS=`) boots the image in QEMU,
logs in as root, runs `poweroff`, and verifies that QEMU exits cleanly. It drives the `./test` expect
script (`./test [PLATFORM] [USERLAND] [CAPS]`), which reads the kernel and disk image the build staged
out of the Docker volumes.

Faster and deeper checks live in `tests/`: `make check` (parse checks, framework unit tests and
artifact assertions — seconds, no QEMU), `make check-probes` (functional in-guest probes against
already-built images), and `make e2e-test` (the self-host proof: a builder guest cross-compiles a
Pi Zero image, which the host then boots). See `tests/README.md`.
