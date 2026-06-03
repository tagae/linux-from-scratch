Linux From Scratch
==================

Automated build of [LFS with systemd](https://www.linuxfromscratch.org/lfs/view/systemd/) targeting ARM hardware. The build is reproducible using an Alpine Linux container as the host.


Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU arm64 virtual machine   | ARMv8 (arm64) |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |

`virt` is the default platform and the primary target for development and testing.


Quick Start
-----------

Enter the Alpine build container (default platform: `virt`):

```shell
make alpine-sh
```

Inside the container, build the cross-compilation toolchain:

```shell
./lfs tools
```

Build the complete LFS system:

```shell
./lfs system
```

Boot in QEMU (creates disk image automatically):

```shell
./lfs qemu
```


Testing
-------

The automated test boots the `virt` image in QEMU, logs in as root, runs `poweroff`, and verifies that QEMU exits cleanly:

```shell
make test
```

This extracts the kernel and disk image from the Docker build volume and runs `./test-virt`.


Commands
--------

```
./lfs [-p PLATFORM] COMMAND

Commands:
  tools            Build cross-compilation toolchain
  system           Build all final system packages
  install <PKG>... Install one or more packages
  image [FILE]     Create bootable disk image
  qemu [FILE]      Boot image in QEMU; creates image if needed

Options:
  -p PLATFORM      Target platform (virt, pi0, pi4, pi5)  [default: virt]
  -d DESTINATION   Install destination (dir, device, or .img)
```


Makefile Targets
----------------

```shell
make test           # Run automated boot test (virt)
make extract        # Copy kernel and image from Docker build volume
make qemu           # Boot image in QEMU interactively
make system         # Build final system (inside Docker container)
make image          # Create image/virt.img
make alpine-sh      # Open interactive build shell
make clean          # Remove work/ directory
make distclean      # Remove work/, tools/, install/
make docker-clean   # Remove Docker build volumes (tools, work, install, image)
```
