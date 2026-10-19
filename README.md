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
* `sudo`, for `make image`, which opens loop devices and mounts file systems (as root, run
  `make image SUDO=`);
* `expect` and QEMU for the platform's architecture, for `make qemu` and `make test`. The `virt`
  platform uses KVM.

Hosts that are not Linux can make the image through Docker Compose instead, with the `docker-`
goals: `make docker-image`, or `make docker-image/pi0-systemd-gnu.img` for a given system. The image
then runs on the host, with QEMU and `expect`: `./lfs qemu` boots it, and `./test` also logs in and
powers off (for a system other than `virt`, set `PLATFORM=pi0`, or pass its key to `./test`).


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

| Capability        | Enables                                                                    |
|-------------------|----------------------------------------------------------------------------|
| `gnupg`           | GnuPG, smart cards included, and `gpg-genkey`, which makes keys in memory  |
| `usb-storage`     | USB sticks and card readers with a FAT file system                         |
| `yubikey`         | Security keys on USB: their OpenPGP card (with `gnupg`) and FIDO2          |
| `yubikey-manager` | `ykman`, to configure a YubiKey (needs `yubikey`); `pcscd` serves the card |

Capabilities can be combined. Each one is described by `lib/capability/<capability>.sh`, which
installs its packages after those of the base system, and by `package/linux/<capability>.config`
when it needs kernel support.


Making OpenPGP Keys on a Raspberry Pi
-------------------------------------

A Raspberry Pi Zero running a system with the `gnupg`, `usb-storage` and `yubikey` capabilities can
make an OpenPGP key whose secret part never touches a disk but the USB stick you back it up to, and
move its subkeys to a YubiKey:

```shell
make docker-image/pi0-systemd-gnu+gnupg+usb-storage+yubikey.img
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

Add the `yubikey-manager` capability to also have `ykman` on the Pi (Python, `cryptography` and the
smart card daemon `pcscd` come with it, about 60 MB):

```shell
make docker-image/pi0-systemd-gnu+gnupg+usb-storage+yubikey+yubikey-manager.img
```

With it, GnuPG reaches the YubiKey through `pcscd` rather than through its own USB driver
(`/etc/gnupg/scdaemon.conf` has `disable-ccid`), so that `gpg` and `ykman` can use the key in turn.
Without it, scdaemon drives the key itself and `ykman` is not installed.


Restrictions
------------

Systems ship without documentation: the man pages, info pages and other documentation a package
installs are left out. Documentation that needs extra tools to build (e.g. systemd's man pages) is
not built.

Boards without a battery-backed clock (the Raspberry Pi) keep time across reboots through
systemd-timesyncd, which saves the clock every minute and at shutdown, and restores it at the next
boot. Every image starts at the time it was made. No NTP servers are configured, as there is no
network.

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
