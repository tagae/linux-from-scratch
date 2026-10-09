Linux From Scratch
==================

Build [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/systemd/)
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

The project currently builds the build tools: a toolchain plus the temporary tools needed to build
packages. Building a bootable system is not part of it at the moment; the disk image and QEMU
support remain for when it returns.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.


Quick Start
-----------

Build the build tools through Docker:

```shell
make tools
```


Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU virtual machine         | host          |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |


Capabilities
------------

| Capability | Enables                                                            |
|------------|--------------------------------------------------------------------|
| `usb`      | Removable USB storage (attach a stick with `USB_DISK=<img>`)       |
| `loop`     | Loop devices                                                       |
| `fat-fs`   | FAT filesystem support                                             |

Capabilities can be combined.


Restrictions
------------

No documentation is built (man pages, info pages, etc.). This might become an opt-in feature in the
future.

Localisation and native language support (NLS) are unsupported. This might become an opt-in feature
in the future.


Make Targets
------------

```shell
make tools    # toolchain + temporary build tools
make image    # produce a disk image from the install tree
make qemu     # boot the image in QEMU (interactive serial console)
make test     # check that the image boots and root can login/poweroff
```

Nothing populates the install tree at the moment, so `image`, `qemu` and `test` have nothing to
work with yet.

Each target defaults to the `virt` platform, the `systemd-gnu` userland, and no capabilities. The
defaults can be changed through variables:

```shell
make image PLATFORM=pi0 CAPS="usb fat-fs"
```

Those three variables make up a *system key*, `<platform>-<userland>[+<caps>]`, which names every
deliverable: the package archives, the install tree, the boot files, and the image. A target can be
named by its system key directly:

```shell
make pi0-systemd-gnu+fat-fs+usb-test
```

Images are file targets under that same key, so `make image/pi0-systemd-gnu+usb.img` produces an
image for the `pi0` platform featuring the `usb` capability.

`make distclean` removes the build state and the tools; `make pristine` also removes downloads,
archives and images.

`make test` boots the image in QEMU, logs in as root, runs `poweroff`, and verifies that QEMU exits
cleanly. It drives the `./test` expect script (`./test [SYSTEM_KEY]`).
