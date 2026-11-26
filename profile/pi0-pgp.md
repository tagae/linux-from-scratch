Pretty Good Privacy for Raspberry Pi Zero
=========================================

A Raspberry Pi Zero Linux to make OpenPGP keys and keep them on USB storage.

Also allows YubiKey management, in particular to import generated OpenPGP keys.


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

   The image won't be modified, since all changes are written to an overlay.

3. Flash the image on an SD card:

   ```shell
   sudo dd if=image/pi0-pgp.img of=/dev/$SD_CARD_DEV bs=4M status=progress
   ```

4. Boot the SD card on the Pi, and log in on the serial console (e.g., through an USB TTL
   adapter), the only console that the system has.


Accounts
--------

The system has two accounts, `root` and `$LFS_USER`, the later defaulting to the user who built the
image. Both accounts are passwordless, unless `LFS_ROOT_PASSWORD` or `LFS_PASSWORD` are set
respectively upon building the image.

The regular account makes keys (`gpg`, `gpg-genkey`), reads and writes the USB stick, and uses a
YubiKey: the security keys' `/dev/hidraw*` devices, which `ykman` and libfido2's tools reach the FIDO2
and OTP interfaces through, belong to the group `users`. The smart card interface is `pcscd`'s, which
GnuPG and `ykman` reach through its socket, as upstream ships it: any account may connect, and every
reader is open to whoever does. The daemon runs as its own account, `pcscd`, in a user namespace, and
opens the readers through the group that ccid's udev rules give them to.

The regular account reads the state of the system (`systemctl status`, `systemctl --failed`),
powers the machine off, restarts it and halts it (`poweroff`, `reboot`, `halt`), and sets the clock
(`timedatectl set-time`), but changes nothing else: systemd, and its time service `timedated`, ask
polkit, which the bus starts when it is first asked, and the rule of the profile
([`50-users.rules`](pi0-pgp/files/etc/polkit-1/rules.d/50-users.rules)) answers yes to the group
`users` for those four, and no to the rest, so `systemctl restart` fails with `Access denied`.
Whoever may set the time may set the time zone too, as the policy of `timedated` has it, but the
zone is on the read-only root, so it stays the image's: `timedatectl set-timezone` fails with
`Read-only file system`, for root as well. Nobody authenticates (there is no PAM), and root needs
no rule.

The issue that `agetty` prints before the login prompt (which names the regular account: the build
replaces `$LFS_USER` in the profile's files), the message of the day that `login` prints after it,
the manual page that the message names, [`pi0-pgp(7)`](pi0-pgp/files/usr/share/man/man7/pi0-pgp.7)
(`man pi0-pgp` on the system tells how to make a key there), the shell profile (`/etc/profile`),
the udev rules that give the group `users` the security keys and USB sticks, and the polkit rule
are files of [`pi0-pgp/files/`](pi0-pgp/files). So is what only this system has: the key procedure
(`gpg-genkey` and the mount units of the stick), the mount units of the memory over the read-only
root ([Nothing Kept](#nothing-kept)), scdaemon's configuration, and the drop-ins that start the
mounts.


Making OpenPGP Keys
-------------------

A Raspberry Pi Zero running the `pi0-pgp` profile can make an OpenPGP key whose secret part never
touches a disk but the USB stick you back it up to, and move its subkeys to a YubiKey:

```shell
make docker-image/pi0-pgp.img
```

Write the image to an SD card, for example with

```shell
sudo dd if=image/pi0-pgp.img of=/dev/disk4 bs=4M status=progress
```

The Zero has one USB data port, the micro-USB one marked *USB*, so connect a hub to it (through an
OTG adapter) and plug both the YubiKey and a USB stick in the hub. The stick holds a FAT file
system labelled `KEYS`, on its first partition or on the whole device, which
[the Pi can make](#formatting-the-usb-stick). Log in as the regular account on the serial console,
whose shell is bash: arrow keys, Tab completion and a history of the session, which is not saved, as
commands carry passphrases.

systemd mounts the stick on `/mnt/keys` the first time anything reads the directory, whoever it is,
and unmounts it when it has not been used for ten seconds: wait that long before pulling the stick
out. Without a stick, the access fails after ten seconds.

Any other USB stick with a FAT file system, whatever its label, is mounted the same way on
`/mnt/usb-storage`, for the regular account to read and write: a udev rule
([`70-usb-sticks.rules`](pi0-pgp/files/usr/lib/udev/rules.d/70-usb-sticks.rules)) links it as
`/dev/usb-storage`, and
[`mnt-usb\x2dstorage.mount`](pi0-pgp/files/usr/lib/systemd/system/mnt-usb%5Cx2dstorage.mount) mounts
that link. Both mounts are `nosuid`, `nodev` and `noexec`. The KEYS stick is never on
`/mnt/usb-storage`, and `gpg-genkey` writes to `/mnt/keys` alone, so that a key never lands on a
stick that was plugged in for another purpose. With two sticks that are not KEYS, the link follows
one of them.

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

GnuPG's home is `~/.gnupg`, for root as for the regular account: in memory, as the home
directories are, so empty after a reboot (`gpg --import /mnt/keys/you@example.org-secret.asc` brings
a key back from the stick). `GPG_TTY=$(tty)` must be set when GnuPG's input is not the terminal
(`echo hi | gpg --clearsign`), for the PIN prompt to find it.


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
* `systemd-tmpfiles` leaves `/etc` and `/srv` as the image has them
  ([`read-only-root.conf`](pi0-pgp/files/etc/systemd/system/systemd-tmpfiles-setup.service.d/read-only-root.conf)).
* The clock starts every boot at the time the image was made (systemd reads it from the date of
  `/usr/lib/clock-epoch`), whatever time was set before.


Keys in Memory
--------------

`gpg-genkey` keeps GnuPG's home, with the keyring, the agent's private keys, the random pool and
the revocation certificate, in `~/.gnupg`, in the memory of the overlay of `/home`
([Nothing Kept](#nothing-kept)), and leaves it there: `gpg` lists and edits the keys at any moment,
until the Pi powers off.

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


Formatting the USB Stick
------------------------

The system makes the FAT file system that the stick needs, with `mkfs.fat` and `fatlabel` (from
`dosfstools`), and finds the stick with `blkid` (from `util-linux`), which lists the SD card's
partitions (`mmcblk0p1` and `mmcblk0p2`) too: the stick is `/dev/sda`, the first on the hub. The
regular account can format it: a udev rule
([`70-usb-sticks.rules`](pi0-pgp/files/usr/lib/udev/rules.d/70-usb-sticks.rules)) gives the block devices of
USB sticks to the group `users`, and leaves the SD card, which is not on USB, to root. This erases
the stick:

```shell
mkfs.fat -I -F 32 -n KEYS /dev/sda
```

The file system is FAT32, labelled `KEYS`, on the whole device (`-I` allows that). To make it on a
partition that the stick already has, name the partition (`/dev/sda1`) and leave `-I` out.
`fatlabel /dev/sda1 KEYS` gives the label to a file system that exists, and any other label
(`fatlabel /dev/sda1 DATA`) moves the stick from `/mnt/keys` to `/mnt/usb-storage`. The stick is
ready at once: systemd mounts it at the next access.

The system has no tool to partition the stick (`fdisk` and `sfdisk` need three more libraries of
`util-linux`): partition it on another computer, which makes the file system go on the first
partition.


YubiKey Management
------------------

The system also has `ykman`, to configure the YubiKey (Python, `cryptography` and the smart card
daemon `pcscd` come with it, about 60 MB). GnuPG reaches the YubiKey through `pcscd` rather than
through its own USB driver (`/etc/gnupg/scdaemon.conf` has `disable-ccid`), so that `gpg` and
`ykman` can use the key in turn.


Testing
-------

`make pi0-pgp-test` boots the system in QEMU's emulation of the Zero, which takes emulated USB
devices (`LFS_QEMU_EXTRA="-device usb-ccid"`, a stick as a `usb-storage` drive) but not a YubiKey: the
key can only be tried on the Pi.

It runs the tests of [`pi0-pgp/test/`](pi0-pgp/test), in order, on one boot (README, Tests):

* The console stays silent after the boot; the issue is on it before the login prompt and the message
  of the day after the login; root and the regular account log in; the regular account powers the
  machine off and restarts it, and is refused the rest.
* The system is healthy as `systemctl status` shows it; the kernel shows errors only on the console,
  zeroes memory as it is freed and has no network; nothing is kept but in memory (the root file
  system read-only even to root, the boot partition unmounted, the home directories and `/var`
  overlays on memory that does not swap, `/tmp` a tmpfs, no swap, the journal in `/run`, no shell
  history); the programs that the system is for, and the manual pages and their index, the page of
  the system among them, are there.
* GnuPG makes a key in its home, `~/.gnupg`, signs, verifies, encrypts and decrypts.
* A USB stick, which the account formats as `man pi0-pgp` says, is mounted and written;
  `gpg-genkey` exports a key to it, and after a boot the key is gone from memory, and the stick's copy
  imports back.
* A smart card reader reaches the account through `pcscd`, which GnuPG and `ykman` share, and
  polkit and `pcscd` run in the sandbox of their units; the machine restarts, and forgets the files
  written to the home directories, `/var` and `/tmp`, and the time that was set.
* The regular account sets the clock, while the time zone stays the image's; `top` runs in batch
  mode and on the console; and the machine powers off.
