Linux From Scratch
==================

Build [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/systemd/)
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.


Quick Start
-----------

Build the whole chain, from the build tools to a disk image that is booted a virtual machine:

```shell
make image
```

Or if you want to also boot the built image:

```shell
make qemu
```


Supported Platforms
-------------------

| Platform | Hardware                       | Architecture  |
|----------|--------------------------------|---------------|
| `virt`   | QEMU virtual machine           | host          |
| `amd64`  | 64-bit x86 PC (QEMU q35)       | x86-64        |
| `arm64`  | 64-bit ARM machine (QEMU virt) | ARMv8 (arm64) |
| `pi0`    | Raspberry Pi Zero              | ARMv6 (arm)   |


Capabilities
------------

| Capability    | Enables                                                                   |
|---------------|---------------------------------------------------------------------------|
| `gnupg`       | GnuPG, smart cards included, and `gpg-genkey`, which makes keys in memory |
| `usb-storage` | USB sticks and card readers with a FAT file system                        |
| `yubikey`     | Security keys on USB: their OpenPGP card (with `gnupg`) and FIDO2         |

Capabilities can be combined. Each one is described by `lib/capability/<capability>.sh`, which
installs its packages after those of the base system, and by `package/linux/<capability>.config`
when it needs kernel support.


Restrictions
------------

Systems ship without documentation: the man pages, info pages and other documentation a package
installs are left out. Documentation that needs extra tools to build (e.g. systemd's man pages) is
not built.

Localisation and native language support (NLS) are unsupported. This might become an opt-in feature
in the future.


Make Targets
------------

```shell
make tools    # toolchain + temporary build tools
make system   # build the system for the platform into the install tree
make image    # produce a disk image from the install tree
make qemu     # boot the image in QEMU (interactive serial console)
make test     # check that the image boots and root can login/poweroff
```

`make system` starts from an empty install tree each time, so `image`, `qemu` and `test` use the
system built by the latest run. Running `make` without a goal runs `test`.

Each target defaults to the `virt` platform, the `systemd-gnu` userland, and no capabilities. The
defaults can be changed through variables:

```shell
make image PLATFORM=pi0 CAPS="gnupg usb-storage"
```

Those three variables make up a *system key*, `<platform>-<userland>[+<caps>]`, which names every
deliverable: the install tree, the boot files, and the image. A target can be named by its system
key directly:

```shell
make pi0-systemd-gnu+gnupg+usb-storage-test
```

Images are file targets under that same key, so `make image/pi0-systemd-gnu+usb-storage.img`
produces an image for the `pi0` platform featuring the `usb-storage` capability.

Package archives are filed under the key of the system as it stands when they are built: the base
system's under `<platform>-<userland>`, and each capability's under that key extended with the
capabilities added so far, in the system key's order. Systems thus share the archives of what they
have in common, the base system's in particular.

`make distclean` removes the build state and the tools; `make pristine` also removes downloads,
archives and images.

`make test` boots the image in QEMU, logs in as root, runs `poweroff`, and verifies that QEMU exits
cleanly. It drives the `./test` expect script (`./test [SYSTEM_KEY]`).
