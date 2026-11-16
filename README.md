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

  * QEMU for your host's architecture, including `qemu-img`. The `virt` platform's command line
    needs QEMU 11.1 or later (`-object monitor-hmp`).

4. To test booted images (e.g., `make test`),

  * The `expect` command.

5. To invalidate stale archives and to version the project (`make invalidate`, `bin/version`),

  * Git 2.36 or later: the scripts read `bin/gitconfig` in place of the user's Git configuration.


Quick Start
-----------

Build the whole chain, from the build tools to a disk image, boot it, login and power off:

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

A *profile* is a whole system specification: kernel, init system and further packages.

Out of the box profiles are located in `profile/<profile>.sh`.

A profile is named `<platform>[-<name>]`, after the platform it runs on (e.g., `pi0-pgp` runs on
`pi0`), and its name is used as key of all built artefacts: package archives, install tree, boot
files and image.

| Profile   | Platform | System                                                                             |
|-----------|----------|------------------------------------------------------------------------------------|
| `virt`    | `virt`   | Bare-bones virtual machine with only a root account                                |
| `pi0-pgp` | `pi0`    | Raspberry Pi Zero to make OpenPGP keys and keep them on a YubiKey and USB storage  |

A profile can have documentation of its own, `profile/<profile>.md`: for `pi0-pgp`, [how to make
OpenPGP keys on a Raspberry Pi](profile/pi0-pgp.md).

A profile can have a regular account besides root (`pi0-pgp` does). `LFS_USER` names it, by default
after the user that runs `make`, and `LFS_PASSWORD` is its password, by default its name:

```shell
make image LFS_PROFILE=pi0-pgp LFS_USER=alice LFS_PASSWORD='a password'
```

The account is made when the system is built, and belongs to no package archive.


Kernel Capabilities
-------------------

A *kernel capability*, `package/linux/<capability>.config`, is a kernel configuration bundle.

A capability that differs by architecture has a part for each:
`package/linux/<capability>.<architecture>.config`. One that differs by platform has a part for each
platform: `package/linux/<capability>.<platform>.config`.

| Capability       | Supports                                                     |
|------------------|--------------------------------------------------------------|
| `btrfs`          | BTRFS root file systems                                      |
| `console`        | The terminal layer that consoles build on                    |
| `fat`            | FAT file systems, such as the Pi's boot partition and sticks |
| `hardening`      | Kernel self-protection and CPU vulnerability mitigations     |
| `serial-console` | A UART as the kernel's console and early console             |
| `systemd`        | systemd requirements                                         |
| `usb`            | USB devices, also from user space through `/dev/bus/usb`     |
| `usb-storage`    | USB sticks and card readers                                  |
| `hidraw`         | HID devices on USB, such as security keys, as `/dev/hidraw*` |


Restrictions
------------

Systems ship without documentation, except the man and info pages of the platforms that have `man=yes`
and `info=yes` in `platform/<platform>.sh` (`pi0`): the packages of their profiles install their
pages, and the profile installs `mandoc` and `texinfo` to read them (`man gpg`, `info gnupg`). The
other documentation a package installs (`/usr/share/doc`) is left out. Pages that need tools that no
build has are not made: the man pages of systemd and shadow (they need `xsltproc`) and of kmod
(`scdoc`). A profile can turn either off with `man=no` or `info=no`.

Boards without a battery-backed clock (the Raspberry Pi) keep time across reboots through
systemd-timesyncd, which saves the clock every minute and at shutdown, and restores it at the next
boot. Every image starts at the time it was made. No NTP servers are configured, as there is no
network.

Images are in UTC. `LFS_TIMEZONE`, set to a name from the time zone database, gives an image of a
profile that installs `tzdata` another zone, e.g. `make image LFS_PROFILE=pi0-pgp
LFS_TIMEZONE=Europe/Berlin`. The clock stays in UTC; the zone only changes how time is shown. The
package carries the whole database, so `TZ` and `/etc/localtime` can name any other zone on the
device.

Localisation and native language support (NLS) are unsupported. This might become opt-in in the
future.


Make Targets
------------

```shell
make fetch            # download the sources of every package, for every profile, into download/
make tools-bootstrap  # native toolchain + temporary tools, from the host's
make tools            # toolchain + temporary build tools
make system           # build the system for the platform into the install tree
make image            # produce a disk image from the install tree
make qemu             # boot the image in QEMU (interactive serial console)
make test             # check that the image boots and root can login/poweroff
```

`make system` starts from an empty install tree each time, so `image`, `qemu` and `test` use the
system built by the latest run. Running `make` without a goal runs `test`.

The builds download what they need as they go. `make fetch` downloads it all first, with the host's
`wget`, so that a source that an upstream server does not give stops it there, and the builds find
the files in `download/`: they fetch nothing but the Rust crates of `cryptography`.

A package builds again only when its archive is gone, so after changing a recipe, a patch, a kernel
option or a framework file, run `make invalidate` (`make docker-invalidate` for the build through
Docker): it deletes the archives that the changes since its last run make stale, uncommitted ones
included. Each key of `archive/` (the profiles' and `tools`) records its own state, so its first
run, with nothing recorded, deletes all of that key's archives.

Each target defaults to the `virt` profile. The default can be changed through a variable:

```shell
make image LFS_PROFILE=pi0-pgp
```

The variables that `lfs` reads all start with `LFS_`, so that none of them clashes with a variable
of the caller's environment, and `lfs` ignores every other.

The profile's name is the key of every deliverable: the install tree, the boot files, and the image. A
target can be named by its profile directly:

```shell
make pi0-pgp-test
```

Images are file targets under that same key, so `make image/pi0-pgp.img` produces the image of the
`pi0-pgp` profile. An image is as small as its system allows: its root file system has only the room
that btrfs leaves in it, which grows with the system. An image appears only once it is complete.
`make qemu` and `make test` boot it through an overlay, `image/<key>.qcow2`, which keeps what the
system writes until the image is made anew, so that the image stays as it was made, to be written to
a card.

Package archives are filed under the key of the profile, `archive/<profile>/`: the cross toolchain's,
the kernel's and those of every package the profile installs. Profiles share no archive but those of
the build tools.

The build tools run on the build machine whatever the platform, so their archives are filed under
the key `tools` and built once, for every system. Systems of different profiles can therefore be
built at once, each build using all the cores:

```shell
make -j docker-test docker-pi0-pgp-test
```

Make builds the tools first, then the systems side by side. The builds share the tools directory
(the cross toolchain of each platform lives there in files named after its triplet, but for a few,
such as `libcc1` and the documentation, which each build rewrites when it extracts its own), the
downloads and the tools' archives, and nothing else: each profile unpacks its sources, builds,
installs and archives apart. Memory limits it more than cores do: each build runs `-j$(nproc)`, and
two cross gcc compiles at once need more than 12 GiB (the compiler is killed while it compiles
`gimple-match-*.cc`), so give the build machine, or the Colima VM, 24 GiB or more. One limit
remains: a profile that installs a build tool that depends on the platform (`pi0-pgp`, whose Rust
targets the platform's architecture) cannot be built while another profile that does is, as both
write the same files in the tools directory. Builds that start from scratch apart, rather than from
one `make`, would both build the tools: build them first (`make docker-tools`).

`make distclean` removes the build state and the tools; `make pristine` also removes downloads,
archives and images.

`make test` boots the image in QEMU, logs in as root, runs `poweroff`, and verifies that QEMU exits
cleanly. It drives the `check/boot` expect script (`check/boot [PROFILE]`).


Software Bill of Materials
--------------------------

An image file comes with an [SPDX][SPDX] 2.3 document in JSON next to it,
`image/<key>.spdx.json`, which says what the image holds: its SHA-256, and each upstream package in
the system, with its version, licence, the URL and SHA-256 of its source, and the identifiers that
vulnerability scanners match, its CPE as the NVD names it, or its PyPI package URL. The licences of
the recipes are SPDX expressions; the two that SPDX does not list (the Pi firmware's and the time
zone database's) come with their text. An image counts as built only along with its document: an
image without one is made anew.

The document can be checked with the SPDX project's validator, and scanned for known
vulnerabilities by [Grype](https://github.com/anchore/grype):

```shell
make sbom-check            # validates every document under image/ (fetches the validator from PyPI)
make vulnerability-check   # scans them with Grype, as CI does (fetches Grype, its data, CVE records)
```

CI builds and boots the `virt` and `pi0-pgp` systems, validates the document of each image with the
same `make sbom-check`, and scans the document of each image after each of its runs on main, with
the vulnerability data of the day, as `make vulnerability-check` does: the badge above fails when
Grype finds, in either image, a vulnerability of high or critical severity that a newer version
fixes, and the findings are in the repository's code scanning alerts. The scan reports, and leaves
CI's own result alone. It leaves out the findings of the kernel that the kernel's own CVE records
show it does not have (fixed in its line, or in code that its build did not read, which
`<image>.kernel-files` lists), and lists them in an OpenVEX document, `<image>.openvex.json`, which
CI keeps with the findings.

A block device gets no document, as it is no file to take the digest of: make the image first, and
write it to the device. The document does not yet list the patches applied to the sources
(`docs/sbom-design.md`).

[SPDX]: https://spdx.github.io/spdx-spec/v2.3/
