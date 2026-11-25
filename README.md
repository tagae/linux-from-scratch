Linux From Scratch
==================

[![Vulnerability scan](https://github.com/tagae/linux-from-scratch/actions/workflows/vulnerabilities.yaml/badge.svg)](https://github.com/tagae/linux-from-scratch/actions/workflows/vulnerabilities.yaml)

Build [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/systemd/)
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.


Requirements
------------

You can skip these requirements if you intend to work through Docker.

Else, you need a Linux host with the following utilities.

1. To build the tools (e.g., `make tools`),

  * A C and C++ toolchain.
  * The `curl`, `wget`, `rsync`, `gawk`, `bison`, `python3`, `patchelf` commands.
  * CA certificates.

2. To build images (e.g., `make image`),

  * A working `sudo` command.

3. To be able to boot images in a VM (e.g., `make qemu`),

  * QEMU 11.1+ including `qemu-img`.

4. To test booted images (e.g., `make test`),

  * The `expect` command.

5. To version the project,

  * Git 2.36+: the scripts read `bin/gitconfig` in place of the user's Git configuration.


Quick Start
-----------

Build a toolchain, use it to build a disk image, boot it, and run the tests of the profile (log in,
power off...):

```shell
make test
```

If you prefer working through Docker:

```shell
make docker-test
```


Supported Platforms
-------------------

| Platform | Hardware             | Architecture |
|----------|----------------------|--------------|
| `virt`   | QEMU virtual machine | host         |
| `pi0`    | Raspberry Pi Zero    | ARMv6 (arm)  |



Profiles
--------

A *profile* is a whole system specification: kernel, init system and installed packages.

A profile is named `<platform>[-<name>]`, after the platform on which it is meant to run (`pi0-pgp`
runs on `pi0`); the name is used as key of all built artefacts: package archives, system tree, boot
files and image.

Out of the box profiles are located in `profile/<profile>.sh`.
See `profile/<profile>.md` for profile-specific documentation.

root has no password, so it logs in on the console without one, unless `$LFS_ROOT_PASSWORD` sets it.

Systems of different profiles can be built at once:

```shell
make -j docker-test docker-pi0-pgp-test
```

Kernel Capabilities
-------------------

A *kernel capability*, `package/linux/<capability>.config`, is a kernel configuration bundle.

Capabilities can differ by architecture: `package/linux/<capability>.<architecture>.config`.

Capabilities can also differ platform: `package/linux/<capability>.<platform>.config`.

| Capability       | Supports                                                     |
|------------------|--------------------------------------------------------------|
| `btrfs`          | BTRFS root file systems                                      |
| `console`        | The terminal layer that consoles build on                    |
| `devtmpfs`       | Device nodes in /dev, mounted before init starts             |
| `fat`            | FAT file systems, such as the Pi's boot partition and sticks |
| `hardening`      | Kernel self-protection and CPU vulnerability mitigations     |
| `modules`        | Loadable kernel modules, and their protection                |
| `overlay`        | Overlay file systems, such as memory over a read-only root   |
| `serial-console` | A UART as the kernel's console and early console             |
| `systemd`        | systemd requirements                                         |
| `usb`            | USB devices, also from user space through `/dev/bus/usb`     |
| `usb-storage`    | USB sticks and card readers                                  |
| `hidraw`         | HID devices on USB, such as security keys, as `/dev/hidraw*` |
| `zero-on-free`   | Zeroing of memory as it is freed, so secrets do not linger   |


Time & Date
-----------

Every image starts at the time it was made.

Images are in UTC. To use another zone, install the `tzdata` package and pass the dedisred zone
with `LFS_TIMEZONE` (e.g., `make image LFS_PROFILE=pi0-pgp LFS_TIMEZONE=Europe/Berlin`). The clock
stays in UTC; the zone only changes how time is shown.

A board without a battery-backed clock (the Raspberry Pi Zero) starts every boot at the time the
image was made, which systemd takes from the modification time of `/usr/lib/clock-epoch`: the
`pi0-pgp` profile keeps nothing across boots, the time included, and is set by hand.

Localisation
------------

Localisation and native language support (NLS) are unsupported. This might become opt-in in the
future.

Users
-----

A profile can have a regular account besides root. `LFS_USER` provides the username (by default,
equal to `$USER`), and `LFS_PASSWORD` the password (by default none, so the account logs in on the
console without one, like root):

```shell
make image LFS_PROFILE=pi0-pgp LFS_ROOT_PASSWORD='a root password' LFS_USER=alice LFS_PASSWORD='a password'
```


Tests
-----

`make test` boots the image in QEMU and runs the tests of the profile on it: the files of
`profile/<profile>/test/`, in the order of their names (`01-boot.exp`, `02-root-login.exp`...). The
first boots the machine and the last powers it off; each in between logs in, checks what it is about,
and logs out, on the one console. The suite ends at the first failure, and says which test, why, and
what the console showed last. The tests start from the image as it was built, whatever earlier runs
left, and leave it as it was.

The accounts are those that the image was built with, so the tests read the same variables
(`LFS_USER`, `LFS_PASSWORD`, `LFS_ROOT_PASSWORD`).

```shell
check/test pi0-pgp        # the same as make pi0-pgp-test, without building
```


Disk Images
-----------

When an image is booted through QEMU, disk writes are sent to an `image/<key>.qcow2` overlay, so
that the original image stays unmodified.

### File Manifests

Next to the image, a plain text file lists every file of each of its file systems:
`image/<key>.root.txt` for the root file system, and `image/<key>.boot.txt` for the
boot partition when there is any.


### Software Bill of Materials

Image files come with an [SPDX][SPDX] document, `image/<key>.spdx.json`, which provides a hash of
the image, and describes each upstream package.

The document can be checked with the SPDX project's validator, and scanned for known
vulnerabilities by [Grype](https://github.com/anchore/grype):

```shell
make sbom-check            # validates every document under image/ (fetches the validator from PyPI)
make vulnerability-check   # scans them with Grype, as CI does (fetches Grype, its data, CVE records)
```

[SPDX]: https://spdx.github.io/spdx-spec/v2.3/
