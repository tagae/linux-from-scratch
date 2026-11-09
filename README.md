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


Requirements
------------

The rules build directly on a Linux host, which needs:

* the tools that `Dockerfile.bootstrap` installs: a C and C++ toolchain (`build-essential`), `curl`,
  `wget`, `rsync`, `gawk`, `bison`, `python3`, `patchelf` and CA certificates;
* `sudo`, for `make image`, which makes the system's files root's (as root, run `make image SUDO=`);
* `expect`, and QEMU for the platform's architecture with `qemu-img`, for `make qemu` and
  `make test`. The `virt` platform uses KVM.

Hosts that are not Linux can make the image through Docker Compose instead, with the `docker-`
goals: `make docker-image`, or `make docker-image/pi0-systemd-gnu.img` for a given system. The image
then runs on the host, with QEMU and `expect`: `./lfs qemu` boots it, and `./test` also logs in and
powers off (for a system other than `virt`, set `PLATFORM=pi0`, or pass its key to `./test`).
`make docker-test` makes the image and runs `./test`, as `make test` does without Docker.


Supported Platforms
-------------------

| Platform | Hardware                       | Architecture  |
|----------|--------------------------------|---------------|
| `virt`   | QEMU virtual machine           | host          |
| `amd64`  | 64-bit x86 PC (QEMU q35)       | x86-64        |
| `arm64`  | 64-bit ARM machine (QEMU virt) | ARMv8 (arm64) |
| `pi0`    | Raspberry Pi Zero              | ARMv6 (arm)   |


Features and Kernel Fragments
-----------------------------

A *feature* is a tool set for the system's users. Its packages, listed in `feature/<feature>.sh`,
are installed after the base system and the kernel. Features can be combined.

| Feature           | Provides                                                                  | Kernel fragments  |
|-------------------|---------------------------------------------------------------------------|-------------------|
| `fido2`           | libfido2's tools for FIDO2 security keys, such as a YubiKey               | `hidraw usb`      |
| `gnupg`           | GnuPG, smart cards included, and `gpg-genkey`, which makes keys in memory | `usb usb-storage` |
| `yubikey-manager` | `ykman`, to configure a YubiKey; `pcscd` serves the card                  | `hidraw usb`      |

A *kernel fragment*, `package/linux/<fragment>.config`, is the kernel configuration for a kind of
device. A feature lists on a `# Linux:` line of its file every fragment it relies on, as a fragment
brings in no other, and the system's kernel gets the fragments of all its features.

| Fragment      | Supports                                                     |
|---------------|--------------------------------------------------------------|
| `usb`         | USB devices, also from user space through `/dev/bus/usb`     |
| `usb-storage` | USB sticks and card readers with a FAT file system           |
| `hidraw`      | HID devices on USB, such as security keys, as `/dev/hidraw*` |


Making OpenPGP Keys on a Raspberry Pi
-------------------------------------

A Raspberry Pi Zero running a system with the `gnupg` feature can make an OpenPGP key whose secret
part never touches a disk but the USB stick you back it up to, and move its subkeys to a YubiKey:

```shell
make docker-image/pi0-systemd-gnu+gnupg.img
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

Add the `yubikey-manager` feature to also have `ykman` on the Pi (Python, `cryptography` and the
smart card daemon `pcscd` come with it, about 60 MB):

```shell
make docker-image/pi0-systemd-gnu+gnupg+yubikey-manager.img
```

With it, GnuPG reaches the YubiKey through `pcscd` rather than through its own USB driver
(`/etc/gnupg/scdaemon.conf` has `disable-ccid`), so that `gpg` and `ykman` can use the key in turn.
Without it, scdaemon drives the key itself and `ykman` is not installed.

The same features build for the `virt` platform, to try the workflow in QEMU without a Pi:

```shell
make docker-image/virt-systemd-gnu+gnupg+yubikey-manager.img
```

It boots on the Mac's own architecture with the host's accelerator, and QEMU takes the USB devices
(`QEMU_EXTRA="-device usb-host,hostbus=…,hostport=…"`, a stick as a `usb-storage` drive).


Restrictions
------------

Systems ship without documentation: the man pages, info pages and other documentation a package
installs are left out. Documentation that needs extra tools to build (e.g. systemd's man pages) is
not built.

Boards without a battery-backed clock (the Raspberry Pi) keep time across reboots through
systemd-timesyncd, which saves the clock every minute and at shutdown, and restores it at the next
boot. Every image starts at the time it was made. No NTP servers are configured, as there is no
network.

Images are in UTC. `TIMEZONE`, set to a name from the time zone database, gives an image another
zone, e.g. `make image TIMEZONE=Europe/Berlin`. The clock stays in UTC; the zone only changes how
time is shown. The system carries the whole database, so `TZ` and `/etc/localtime` can name any
other zone on the device.

Localisation and native language support (NLS) are unsupported. This might become an opt-in feature
in the future.


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

Each target defaults to the `virt` platform, the `systemd-gnu` userland, and no features. The
defaults can be changed through variables:

```shell
make image PLATFORM=pi0 FEATURES="fido2 gnupg"
```

Those variables make up a *system key*, `<platform>-<userland>[+<feature>...]`, with the features
in alphabetical order, which names every deliverable: the install tree, the boot files, and the
image. A target can be named by its system key directly:

```shell
make pi0-systemd-gnu+gnupg-test
```

Images are file targets under that same key, so `make image/pi0-systemd-gnu+fido2.img` produces an
image for the `pi0` platform featuring `fido2`. An image is as small as its system allows: its root
file system has only the room that btrfs leaves in it, which grows with the system (some 30 MB
without features, 50 MB with those above). `IMAGE_SIZE` makes it larger (e.g. `IMAGE_SIZE=1G`), the
root file system filling it. An image appears only once it is complete. `make qemu` and `make test`
boot it through an overlay, `image/<key>.qcow2`, which keeps what the system writes until the image
is made anew, so that the image stays as it was made, to be written to a card.

Package archives are filed under the key of the system as it stands when they are built: the base
system's under `<platform>-<userland>`, the kernel's under that key extended with the kernel
fragments of all the system's features, in alphabetical order (`pi0-systemd-gnu+hidraw+usb` for
`fido2`), and each feature's under that key extended with the features added so far, in alphabetical
order. Systems thus share the archives of what they have in common: the base system's, and the
kernel of systems whose features rely on the same fragments.

`make distclean` removes the build state and the tools; `make pristine` also removes downloads,
archives and images.

`make test` boots the image in QEMU, logs in as root, runs `poweroff`, and verifies that QEMU exits
cleanly. It drives the `./test` expect script (`./test [SYSTEM_KEY]`).


Software Bill of Materials
--------------------------

An image file comes with an [SPDX][SPDX] 2.3 document in JSON next to it,
`image/<key>.spdx.json`, which says what the image holds: its SHA-256, and for each package in the
system, the SHA-256, version and licence of its archive and the URL and SHA-256 of the upstream
source it was built from. The licences of the recipes are SPDX expressions; the two that SPDX does
not list (the Pi firmware's and the time zone database's) come with their text. An image counts as
built only along with its document: an image without one is made anew.

The document can be checked with the SPDX project's validator, and read by scanners such as Grype:

```shell
pip install spdx-tools
pyspdxtools --infile image/virt-systemd-gnu.spdx.json
```

A block device gets no document, as it is no file to take the digest of: make the image first, and
write it to the device. The document does not yet list the patches applied to the sources, nor
identify packages for vulnerability scanners beyond their name and version (`docs/sbom-design.md`).

[SPDX]: https://spdx.github.io/spdx-spec/v2.3/
