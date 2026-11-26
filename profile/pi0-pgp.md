Air-gapped Privacy System for Raspberry Pi Zero
===============================================

A Raspberry Pi Zero Linux for private, sensitive work, on a computer that is on no network and keeps
nothing of what is done on it. Its uses, the first of which names the profile:

* making OpenPGP keys, keeping them on USB storage and moving their subkeys to a YubiKey
  ([Making OpenPGP Keys](#making-openpgp-keys)), and managing the YubiKey
  ([YubiKey Management](#yubikey-management));
* partitioning USB sticks and drives, making and checking FAT, ext4 and BTRFS file systems on them,
  moving files between them, and copying them whole ([USB Storage](#usb-storage)).


Privacy
-------

* The system is on no network: its kernel has no TCP/IP, no network devices, no Wi-Fi and no
  Bluetooth, and the Zero (unlike the Zero W) has no radio. What goes in or out goes over USB, or
  over the serial console.
* It keeps nothing: the SD card is not written while the system runs ([Nothing
  Kept](#nothing-kept)), the shell saves no history, and the kernel zeroes memory as it is freed.
* The console shows no message of the kernel but errors, so that none lands in the middle of what is
  typed, a passphrase included.

It does not encrypt storage (there is no LUKS), nor check at boot that the SD card holds what was
written to it. Its kernel reads what is plugged into it, and a device or a file system made to
attack it can exploit a flaw in that code: power the Pi off between such a device and secrets.


Quick Start
-----------

1. Build the image with

   ```shell
   make docker-image/pi0-pgp.img LFS_TIMEZONE=Europe/Brussels
   ```

2. Explore it in an emulated host:

   ```shell
   ./lfs qemu image/pi0-pgp.img
   ```

   The image stays unmodified: the writes go to an overlay.

3. Flash the image on an SD card:

   ```shell
   sudo dd if=image/pi0-pgp.img of=/dev/$SD_CARD_DEV bs=4M status=progress
   ```

4. Boot the SD card on the Pi, and log in on the serial console (e.g., through a USB TTL adapter),
   the only console that the system has.


Accounts
--------

The system has two accounts: `root`, and `$LFS_USER`, by default the user who built the image.
Neither has a password unless `LFS_ROOT_PASSWORD` or `LFS_PASSWORD`, respectively, sets one when
the image is built.

The regular account makes keys (`gpg`, `gpg-genkey`), works on USB sticks and drives ([USB
Storage](#usb-storage)), and uses a YubiKey. The security keys' `/dev/hidraw*` devices, through
which `ykman` and libfido2's tools reach the FIDO2 and OTP interfaces, belong to the group `users`.
The smart card interface is `pcscd`'s, which GnuPG and `ykman` reach through its socket, as
upstream ships it: any account may connect, and every reader is open to whoever does. The daemon
runs as its own account, `pcscd`, in a user namespace, and opens the readers through the group that
ccid's udev rules give them to.

The regular account reads the state of the system (`systemctl status`, `systemctl --failed`),
powers the machine off, restarts it and halts it (`poweroff`, `reboot`, `halt`), and sets the clock
(`timedatectl set-time`), but changes nothing else (`systemctl restart` fails with `Access
denied`): systemd and its time service, `timedated`, ask polkit, and the profile's rule
([`50-users.rules`](pi0-pgp/files/etc/polkit-1/rules.d/50-users.rules)) answers yes to the group
`users` for those four, and no to the rest. Whoever may set the time may set the time zone too, as
the policy of `timedated` has it, but the zone is on the read-only root: `timedatectl set-timezone`
fails with `Read-only file system`, for root as well. Nobody authenticates (there is no PAM), and
root needs no rule.

The files of [`pi0-pgp/files/`](pi0-pgp/files) give the system its look and policy: the issue that
`agetty` prints before the login prompt, which names the regular account (the build replaces
`$LFS_USER` in these files); the message of the day, which names the manual page
[`pi0-pgp(7)`](pi0-pgp/files/usr/share/man/man7/pi0-pgp.7); the shell profile; the udev rules and
the polkit rule above; `gpg-genkey` and the mount units of the stick; the mount units of the memory
over the read-only root ([Nothing Kept](#nothing-kept)) and the drop-ins that start the mounts; and
scdaemon's configuration.


USB Storage
-----------

The Zero has one USB data port, the micro-USB one marked *USB*: connect a hub to it (through an OTG
adapter) to plug in several devices. A hard disk may draw more power than the Zero can give: use a
powered hub, or a disk with a supply of its own.

USB sticks, drives and card readers are the block devices `/dev/sda`, `/dev/sdb` and so on, in the
order the system finds them, and their partitions (`/dev/sda1`). `fdisk -l` shows the model and size
of each, and `blkid` the file systems that they hold. A udev rule
([`70-usb-sticks.rules`](pi0-pgp/files/usr/lib/udev/rules.d/70-usb-sticks.rules)) gives them to the
group `users`, and leaves the SD card, which is not on USB, to root: the regular account does all
that this section tells but the mounts that systemd does not make. Check the name of a device before
writing to it, as most of these commands erase without asking.

### Partitioning

`cfdisk`, which has a menu, `fdisk`, and `sfdisk`, for scripts (all from `util-linux`), write
partition tables, GPT and MBR (`dos`) among them, both of which the kernel reads. This erases
`/dev/sda`, and gives it a partition for each of FAT, ext4 and BTRFS, the last taking the rest:

```shell
sfdisk --wipe always --wipe-partitions always /dev/sda <<END
label: gpt
size=1GiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7
size=1GiB, type=L
type=L
END
```

The first type is GPT's "basic data", which FAT partitions have, and `L` is Linux's. The `--wipe`
options remove the signatures of earlier file systems, which `sfdisk`, reading a script, otherwise
leaves, with a warning.

Run by the regular account, `sfdisk` and `fdisk` report that re-reading the partition table failed,
as only root may ask the kernel to; udev has the table re-read when these tools, `cfdisk` too,
close the device. `sfdisk` refuses a device with a mounted partition, and `fdisk` warns of it.

### File Systems

| File system | Makes it     | Checks it     | Labels it                | Package       |
|-------------|--------------|---------------|--------------------------|---------------|
| FAT         | `mkfs.fat`   | `fsck.fat`    | `fatlabel`               | `dosfstools`  |
| ext4        | `mkfs.ext4`  | `fsck.ext4`   | `e2label`                | `e2fsprogs`   |
| BTRFS       | `mkfs.btrfs` | `btrfs check` | `btrfs filesystem label` | `btrfs-progs` |

```shell
mkfs.fat -F 32 -n PHOTOS /dev/sda1
mkfs.ext4 -L archive /dev/sda2
mkfs.btrfs -L backup /dev/sda3

fsck.fat -n /dev/sda1
fsck.ext4 -f /dev/sda2
btrfs check /dev/sda3
```

Where there is a file system, `mkfs.ext4` asks before it erases it, `mkfs.btrfs` refuses to unless
`-f` tells it to, and `mkfs.fat` does not ask. `mkfs.btrfs` warns the regular account that it could
not register the device, which udev does. A file system is checked while it is not mounted:
`fsck.fat -n` and `btrfs check` change nothing, and `fsck.ext4` asks before it repairs what it finds.

`e2fsprogs` also resizes, tunes and inspects ext file systems (`resize2fs`, `tune2fs`, `dumpe2fs`,
`debugfs`), and `btrfs-progs` copies files out of a damaged BTRFS (`btrfs restore`). BTRFS comes
without its manual pages, which take Sphinx to build (`btrfs --help` lists the commands), and its
programs without zstd and LZO: the kernel reads the files that these compress, which `btrfs restore`
cannot.

### Mounting and Moving Files

systemd mounts two FAT file systems for the regular account, the first time anything reads their
directory, whoever it is:

* the one labelled `KEYS` on `/mnt/keys`,
* and one with another label on `/mnt/usb-storage`: a udev rule
  ([`70-usb-sticks.rules`](pi0-pgp/files/usr/lib/udev/rules.d/70-usb-sticks.rules)) links it as
  `/dev/usb-storage`, which
  [`mnt-usb\x2dstorage.mount`](pi0-pgp/files/usr/lib/systemd/system/mnt-usb%5Cx2dstorage.mount)
  mounts. Of several, the link follows one.

It unmounts them when they have not been used for ten seconds: wait that long before pulling a
device out. Without a device, the access fails after ten seconds. Both mounts are `nosuid`, `nodev`
and `noexec`. The KEYS stick is never on `/mnt/usb-storage`, and `gpg-genkey` writes to `/mnt/keys`
alone, so that a key never lands on a stick that was plugged in for another purpose.

Nothing else is mounted by itself: root mounts ext4 and BTRFS, and further FAT file systems, and
unmounts them before the device is pulled out.

```shell
mount --mkdir -o nosuid,nodev,noexec /dev/sdb2 /tmp/archive
cp -r /mnt/usb-storage/photos /tmp/archive
umount /tmp/archive
```

The top directory of a new ext4 or BTRFS file system is root's, whoever made it. Mounting hands a
file system to the kernel ([Privacy](#privacy)).

### Copying Devices

`dd`, of the core utilities, copies a device or a partition to another, or to a file, block by
block. This copies `/dev/sda` over `/dev/sdb`, which must be at least as large:

```shell
dd if=/dev/sda of=/dev/sdb bs=4M conv=fsync status=progress
```

`dd` overwrites what `of=` names without asking, mounted or not. An image of a device goes to a
file on a mounted file system with room for it, as the memory of the system is too small for most.
Writing over flash storage does not erase it for certain: sticks, cards and SSDs keep blocks that no
write reaches.


Making OpenPGP Keys
-------------------

A Raspberry Pi Zero running the `pi0-pgp` profile can make an OpenPGP key whose secret part never
touches a disk but the USB stick you back it up to, and move its subkeys to a YubiKey.

Plug both the YubiKey and a USB stick in a hub ([USB Storage](#usb-storage)). The stick holds a FAT
file system labelled `KEYS`, on its first partition or on the whole device, which
[the Pi can make](#formatting-the-stick-for-the-keys), and which systemd mounts on `/mnt/keys`
([Mounting and Moving Files](#mounting-and-moving-files)). Log in as the regular account on the
serial console, whose shell is bash: arrow keys, Tab completion and a history of the session, which
is not saved, as commands carry passphrases.

1. The Pi has no battery-backed clock, and the system keeps nothing across boots: every boot starts
   at the time the image was made. Keys record the time they are made at, so set it:

   ```shell
   timedatectl set-time '2026-10-19 08:30:00 UTC'
   ```

   Without `UTC`, the time is read in the image's time zone. `timedated` refuses a time before the
   date of the systemd release that it is part of; root's `date -s` sets any.

2. Make the key. The primary key only certifies; it has subkeys to sign, to encrypt and to
   authenticate, none of which expires. GnuPG's home is `~/.gnupg`, in memory (see [Keys in
   Memory](#keys-in-memory)), and the keys stay in it when the command ends. Plug the YubiKey in
   first: its random number generator adds to the Pi's (see [Randomness](#randomness)), which
   makes the command wait a minute; without it, the command warns and relies on the Pi's alone.
   Give the passphrase through the environment, so that it stays out of the process list:

   ```shell
   PASSPHRASE='a long passphrase' gpg-genkey -n 'Your Name' -e you@example.org
   ```

   The root of the stick now holds `you@example.org-secret.asc` (protected by the passphrase),
   `-public.asc` and `-revoke.asc`. The keys are ed25519, with a cv25519 encryption subkey; `-a
   rsa4096` makes RSA keys instead.

3. Move the subkeys to the YubiKey, when you wish: the keys are still in memory, and `gpg
   --list-secret-keys` shows them. Copy each subkey to its slot (the card asks for its Admin PIN):

   ```shell
   gpg --edit-key you@example.org
   ```

   At the `gpg>` prompt: `key 1`, `keytocard` and slot `1` (signature); `key 1` again to deselect
   it; `key 2`, `keytocard` and slot `2` (encryption); `key 2`; `key 3`, `keytocard` and slot `3`
   (authentication); then `save`. `gpg --card-status` lists the three keys on the card. The stick
   keeps the whole secret key.

GnuPG's home, `~/.gnupg` for root as for the regular account, is empty after a reboot: `gpg
--import /mnt/keys/you@example.org-secret.asc` brings a key back from the stick. `GPG_TTY=$(tty)` must be set when GnuPG's input is not the terminal
(`echo hi | gpg --clearsign`), for the PIN prompt to find it.

### Formatting the Stick for the Keys

`mkfs.fat` makes the file system that the stick needs. This erases the stick, `/dev/sda` here:

```shell
mkfs.fat -I -F 32 -n KEYS /dev/sda
```

The file system is FAT32, labelled `KEYS`, on the whole device (`-I` allows that). To make it on a
partition, name the partition (`/dev/sda1`) and leave `-I` out. `fatlabel /dev/sda1 KEYS` gives the
label to a file system that exists, and any other label (`fatlabel /dev/sda1 DATA`) moves the stick
from `/mnt/keys` to `/mnt/usb-storage`. The stick is ready at once: systemd mounts it at the next
access.


Nothing Kept
------------

The system forgets what is done on it when the Pi powers off: the files that the accounts write,
the logins that `login` records, the time that was set. Nothing is written to the SD card while the
system runs.

* The root file system is read-only: the kernel mounts it so (the `ro` of `cmdline.txt`), and its
  btrfs subvolume is read-only too, so that a remount alone does not make it writable. The boot
  partition is not mounted (`mount /dev/mmcblk0p1 /boot` mounts it for root).
* The home directories (`/home` and root's `/root`) and `/var` are overlays
  ([`home.mount`](pi0-pgp/files/usr/lib/systemd/system/home.mount),
  [`root.mount`](pi0-pgp/files/usr/lib/systemd/system/root.mount),
  [`var.mount`](pi0-pgp/files/usr/lib/systemd/system/var.mount)): the image's directory underneath,
  which holds what the build put there, and memory on top, which takes what is written, deletions
  included. The memory is one tmpfs, `/run/memory`
  ([`run-memory.mount`](pi0-pgp/files/usr/lib/systemd/system/run-memory.mount)), which only root
  opens, and which holds 64 MB at most. `/tmp` is systemd's tmpfs, the journal is in `/run`, and
  there is no swap.
* `systemd-tmpfiles` leaves `/etc` and `/srv` as the image has them ([`read-only-root.conf`][tmpfiles]).
* The clock starts every boot at the time the image was made (systemd reads it from the date of
  `/usr/lib/clock-epoch`), whatever time was set before.


Keys in Memory
--------------

`gpg-genkey` keeps GnuPG's home, with the keyring, the agent's private keys, the random pool and
the revocation certificate, in `~/.gnupg`, in the memory of the overlay of `/home`
([Nothing Kept](#nothing-kept)): `gpg` lists and edits the keys until the Pi powers off.

* The memory, `/run/memory`, is mounted `noswap`: the kernel never writes its pages to swap. A tmpfs
  without that option can, `/dev/shm` and `/run` included, if the kernel has swap: the guarantee
  does not depend on the kernel's configuration.
* Only the regular account opens `~/.gnupg` (mode 0700), and nothing runs from `/home` (`noexec`,
  `nosuid` and `nodev`).
* `gpg-genkey` refuses to start unless `/home` is an overlay that writes to `/run/memory`, and that
  a tmpfs mounted `noswap`.
* The agent, which keeps the passphrase for ten minutes, quits when `gpg-genkey` ends, however it
  ends, and starts again when `gpg` needs it.
* Nothing deletes the keys: they go when the Pi powers off. Unmounting the tmpfs frees its pages,
  and the kernel zeroes every page that it frees (`init_on_free`, the capability
  [`zero-on-free`](../package/linux/zero-on-free.config)), which costs run time on every
  allocation.


Randomness
----------

GnuPG takes the randomness of a key from the kernel, whose generator is seeded from a pool of what
it gathers. Each input is *credited* with the number of unpredictable bits that it is trusted to
hold, and the generator serves nobody until 256 bits have been credited; from then on its output
is unpredictable however much of it is read, and it reseeds from the pool at least once a minute.
Input that is mixed in without credit counts for nothing towards those 256 bits, but whatever it
is worth goes into the seed all the same: a weak input cannot weaken it.

* The Pi's hardware random number generator (`HW_RANDOM_BCM2835`, in
  [`pi0.config`](../package/linux/pi0.config)) feeds the pool from the boot on, with full credit:
  the generator is ready within seconds, long before anyone logs in. The SoC has no cycle counter,
  so the kernel's own timing jitter adds little to it.
* `gpg-genkey` mixes 64 bytes of the YubiKey's own generator into the pool (`SCD RANDOM 64` through
  the agent), without credit, so that the keys depend on two independent generators, either of which
  would make them unpredictable. Only root may credit what it writes, and the YubiKey has no need
  of credit: the Pi's generator has made the kernel's ready already. It then waits a minute, for the
  kernel to reseed with it, and has the agent that makes the keys start after that.
* GnuPG's own random seed file (`random_seed`) lives in `~/.gnupg`, which is empty at every boot,
  and so does systemd's seed of the kernel's pool (`/var/lib/systemd/random-seed`), in the memory of
  `/var`: no seed outlives a boot, or is on the SD card for someone who has had it to read.

To see the hardware generator at work:

```shell
cat /sys/class/misc/hw_random/rng_current            # bcm2835-rng
cat /sys/module/rng_core/parameters/default_quality  # 1024: full credit
dmesg | grep -i crng                                 # crng init done, early in the boot
```


YubiKey Management
------------------

The system also has `ykman`, to configure the YubiKey (Python, `cryptography` and the smart card
daemon `pcscd` come with it, about 60 MB). GnuPG reaches the YubiKey through `pcscd` rather than
through its own USB driver (`/etc/gnupg/scdaemon.conf` has `disable-ccid`), so that `gpg` and
`ykman` can use the key in turn.


Testing
-------

`make pi0-pgp-test` boots the system in QEMU's emulation of the Zero, which takes emulated USB
devices (`LFS_QEMU_EXTRA="-device usb-ccid"`, a stick as a `usb-storage` drive) but not a YubiKey:
the key can only be tried on the Pi.

It runs the tests of [`pi0-pgp/test/`](pi0-pgp/test) in order, on one boot ([README,
Tests](../README.md#tests)), each named after what it checks: the console and the accounts, and
what polkit lets them do; the kernel, the memory that keeps nothing, and the programs and manual
pages of the system; GnuPG, `gpg-genkey` and the KEYS stick; the smart card reader and the units'
sandboxes; restarts, which forget what was done; the clock and `top`; and the partitions, file
systems, mounts and copies of a drive plugged into the running machine.

[tmpfiles]: pi0-pgp/files/etc/systemd/system/systemd-tmpfiles-setup.service.d/read-only-root.conf
