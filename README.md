Linux From Scratch
==================

Automated build of [LFS with systemd](https://www.linuxfromscratch.org/lfs/view/systemd/).

Built images contain a minimal systemd/Busybox Linux system that boots cleanly and is accessible
through the serial console.


Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU arm64 virtual machine   | ARMv8 (arm64) |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |

The `virt` platform is the default.


Quick Start
-----------

Build the the cross-compilation toolchain:

```shell
make tools
```

Build the complete system:

```shell
make system
```

Emulation
---------

Each emulation target will create the needed image automatically.

Boot a `virt` machine in QEMU:

```shell
make qemu-virt
```

Boot a Raspberry Pi Zero machine in QEMU:

```shell
make qemu-raspi0
```

Boot a Raspberry Pi 4 Model B machine in QEMU:

```shell
make qemu-raspi4b
```

Testing
-------

The automated test boots the `virt` image in QEMU, logs in as root, runs `poweroff`, and verifies
that QEMU exits cleanly:

```shell
make test
```

This extracts the kernel and disk image from the Docker build volume and runs `./test-virt`.
