Linux From Scratch
==================

Automated build of [LFS with systemd](https://www.linuxfromscratch.org/lfs/view/systemd/).


Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU arm64 virtual machine   | ARMv8 (arm64) |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |

The `virt` platform is the default and primary target for development and testing.


Quick Start
-----------

Build the the cross-compilation toolchain:

```shell
make tools
```

Build the complete LFS system:

```shell
make system
```

Boot in QEMU (creates disk image automatically):

```shell
make qemu
```


Testing
-------

The automated test boots the `virt` image in QEMU, logs in as root, runs `poweroff`, and verifies that QEMU exits cleanly:

```shell
make test
```

This extracts the kernel and disk image from the Docker build volume and runs `./test-virt`.
