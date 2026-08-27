Linux From Scratch
==================

Build [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/systemd/)
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

Built images contain a minimal Linux system that boots cleanly and is accessible through the serial
console. Further opt-in capabilities can be layered on top of the base system, for example to add
networking support.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.


Supported Platforms
-------------------

| Platform | Hardware                     | Architecture  |
|----------|------------------------------|---------------|
| `virt`   | QEMU virtual machine         | host          |
| `pi0`    | Raspberry Pi Zero            | ARMv6 (arm)   |
| `pi4`    | Raspberry Pi 4               | ARMv8 (arm64) |
| `pi5`    | Raspberry Pi 5               | ARMv8 (arm64) |


Quick Start
-----------

Build the build tools through Docker, then the default image, and boot it in QEMU, log in as root,
and power off, asserting a clean exit:

```shell
make test
```

Target another platform with `PLATFORM`; the whole chain rebuilds for it:

```shell
make test PLATFORM=pi0
make test PLATFORM=pi4
```

The cross-toolchain is shared by platform. Each platform lives in its own install tree and
image, so they never clobber one another.


Capabilities
------------

| Capability | What it enables                                                     |
|------------|---------------------------------------------------------------------|
| `network`  | Networking: DHCP + DNS (systemd-networkd/-resolved)                 |
| `9p`       | Host file sharing: the project directory mounted over virtio-9p     |
| `usb`      | Removable USB storage (attach a stick with `USB_DISK=<img>`)        |
| `loop`     | Loop devices |
| `fat-fs`   | FAT filesystem support |
| `amnesia`  | Read-only root: the boot medium never written                       |

Capabilities can be combined. Each combination gets its own kernel, install tree and image.

The `9p` capability works only for the `virt` QEMU emulation.

Opt into capabilities with `CAPS`:

```shell
make test CAPS="network 9p"
```


Building and booting by stage
-----------------------------

The stages can be run individually:

```shell
make tools    # cross-toolchain + temporary build tools
make system   # build every package into the target install tree
make image    # produce a bootable disk image
make qemu     # boot the image in QEMU (interactive serial console)
make test     # checks that the image boots and root can login/poweroff
```

Each stage takes the same three variables, defaulting to the `virt` platform, the `systemd`
userland, and no capabilities:

```shell
make system PLATFORM=pi0 USERLAND=busybox CAPS="network 9p"
```

Those three make up a *system key*, `<platform>-<userland>+[<cap>+...]`, which names every
deliverable: the install tree, the boot files, and the image. Capabilities are sorted, and the `+`
is always present, so one combination has exactly one key however you spell the request.

A stage can also be named by its key directly, which is how you build several combinations from one
command line:

```shell
make pi0-busybox+9p+network-test virt-systemd+-test
```

Images are file targets under that same key, so `make image/pi0-busybox+9p+network.img` produces
exactly what the first of those two would boot.

The `distclean` target tears down all built files, and downloaded files.


Testing
-------

`make test` (with optional `PLATFORM=`, `USERLAND=` and `CAPS=`) boots the image in QEMU, logs in as
root, runs `poweroff`, and verifies that QEMU exits cleanly. It drives the `./test` expect script
(`./test [PLATFORM] [USERLAND] [CAPS]`).
