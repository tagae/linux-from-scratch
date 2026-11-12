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

  * QEMU for your host's architecture, including `qemu-img`.

4. To test booted images (e.g., `make test`),

  * The `expect` command.


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


Making OpenPGP Keys on a Raspberry Pi
-------------------------------------

A Raspberry Pi Zero running the `pi0-pgp` profile can make an OpenPGP key whose secret part never
touches a disk but the USB stick you back it up to, and move its subkeys to a YubiKey:

```shell
make docker-image/pi0-pgp.img
```

Write the image to an SD card. The Zero has one USB data port, the micro-USB one marked *USB*, so
connect a hub to it (through an OTG adapter) and plug both the YubiKey and a USB stick in the hub.
The stick holds a FAT file system, on its first partition or on the whole device. Log in as root on
the serial console.

1. The Pi has no battery-backed clock. It restores the time it last saved, and a new image starts at
   the time it was made. Keys record the time they are made at, so set it:

   ```shell
   date -u -s '2026-10-19 08:30:00'
   ```

2. Make the key. The primary key only certifies; it has subkeys to sign, to encrypt and to
   authenticate, none of which expires. GnuPG's home is a new directory under `/run`, a tmpfs, which
   is deleted when the command ends. Give the passphrase through the environment, so that it stays
   out of the process list:

   ```shell
   PASSPHRASE='a long passphrase' gpg-genkey -n 'Your Name' -e you@example.org
   ```

   The root of the stick now holds `you@example.org-secret.asc` (protected by the passphrase),
   `-public.asc` and `-revoke.asc`. The keys are ed25519, with a cv25519 encryption subkey; `-a
   rsa4096` makes RSA keys instead.

3. Move the subkeys to the YubiKey. Import the secret key into a keyring in memory, and copy each
   subkey to its slot (the card asks for its Admin PIN):

   ```shell
   mkdir -p /mnt/usb && mount -t vfat /dev/sda1 /mnt/usb
   export GNUPGHOME=$(mktemp -d /run/gnupg.XXXXXX)
   gpg --import /mnt/usb/you@example.org-secret.asc
   gpg --edit-key you@example.org
   ```

   At the `gpg>` prompt: `key 1`, `keytocard` and slot `1` (signature); `key 1` again to deselect
   it; `key 2`, `keytocard` and slot `2` (encryption); `key 2`; `key 3`, `keytocard` and slot `3`
   (authentication); then `save`. `gpg --card-status` lists the three keys on the card. The stick
   keeps the whole secret key.

   ```shell
   umount /mnt/usb
   ```

`GPG_TTY=$(tty)` must be set when GnuPG's input is not the terminal (`echo hi | gpg --clearsign`),
for the PIN prompt to find it.

The system also has `ykman`, to configure the YubiKey (Python, `cryptography` and the smart card
daemon `pcscd` come with it, about 60 MB). GnuPG reaches the YubiKey through `pcscd` rather than
through its own USB driver (`/etc/gnupg/scdaemon.conf` has `disable-ccid`), so that `gpg` and
`ykman` can use the key in turn.

`make pi0-pgp-test` boots the system in QEMU's emulation of the Zero, which takes emulated USB
devices (`QEMU_EXTRA="-device usb-ccid"`, a stick as a `usb-storage` drive) but not a YubiKey: the
key can only be tried on the Pi.


Restrictions
------------

Systems ship without documentation: the man pages, info pages and other documentation a package
installs are left out. Documentation that needs extra tools to build (e.g. systemd's man pages) is
not built.

Boards without a battery-backed clock (the Raspberry Pi) keep time across reboots through
systemd-timesyncd, which saves the clock every minute and at shutdown, and restores it at the next
boot. Every image starts at the time it was made. No NTP servers are configured, as there is no
network.

Images are in UTC. `TIMEZONE`, set to a name from the time zone database, gives an image of a
profile that installs `tzdata` another zone, e.g. `make image PROFILE=pi0-pgp
TIMEZONE=Europe/Berlin`. The clock stays in UTC; the zone only changes how time is shown. The
package carries the whole database, so `TZ` and `/etc/localtime` can name any other zone on the
device.

Localisation and native language support (NLS) are unsupported. This might become opt-in in the
future.


Make Targets
------------

```shell
make tools-bootstrap  # native toolchain + temporary tools, from the host's
make tools            # toolchain + temporary build tools
make system           # build the system for the platform into the install tree
make image            # produce a disk image from the install tree
make qemu             # boot the image in QEMU (interactive serial console)
make test             # check that the image boots and root can login/poweroff
```

`make system` starts from an empty install tree each time, so `image`, `qemu` and `test` use the
system built by the latest run. Running `make` without a goal runs `test`.

Each target defaults to the `virt` profile. The default can be changed through a variable:

```shell
make image PROFILE=pi0-pgp
```

The profile's name is the key of every deliverable: the install tree, the boot files, and the image. A
target can be named by its profile directly:

```shell
make pi0-pgp-test
```

Images are file targets under that same key, so `make image/pi0-pgp.img` produces the image of the
`pi0-pgp` profile. An image is as small as its system allows: its root file system has only the room
that btrfs leaves in it, which grows with the system. `IMAGE_SIZE` makes it larger (e.g.
`IMAGE_SIZE=1G`), the root file system filling it. An image appears only once it is complete. `make
qemu` and `make test` boot it through an overlay, `image/<key>.qcow2`, which keeps what the system
writes until the image is made anew, so that the image stays as it was made, to be written to a
card.

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
cleanly. It drives the `./test` expect script (`./test [PROFILE]`).


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
pip install spdx-tools
pyspdxtools --infile image/virt-systemd.spdx.json
grype sbom:image/virt-systemd.spdx.json
```

CI builds and boots the `virt` and `pi0-pgp` systems, and scans the document of each image after each of
its runs on main, with the vulnerability data of the day: the badge above fails when Grype finds, in
either image, a vulnerability of high or critical severity that a newer version fixes, and the
findings are in the repository's code scanning alerts. The scan reports, and leaves CI's own result
alone.

A block device gets no document, as it is no file to take the digest of: make the image first, and
write it to the device. The document does not yet list the patches applied to the sources
(`docs/sbom-design.md`).

[SPDX]: https://spdx.github.io/spdx-spec/v2.3/
