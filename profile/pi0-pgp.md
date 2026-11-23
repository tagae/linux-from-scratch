The `pi0-pgp` Profile
=====================

A Raspberry Pi Zero Linux to make OpenPGP keys and keep them on a YubiKey and USB storage.

Accounts
--------

The system has two accounts, both with a shell on the serial console:

* `root`, with no password, unless `LFS_ROOT_PASSWORD` sets one.
* A regular account, for working with keys without administrative rights. Its name is `LFS_USER`,
  which defaults to the name of the user who runs `make`. It has no password, unless `LFS_PASSWORD`
  sets one:

  ```shell
  make docker-image/pi0-pgp.img LFS_USER=alice LFS_PASSWORD='a password'
  ```

The regular account makes keys (`gpg`, `gpg-genkey`), reads and writes the USB stick, and uses a
YubiKey: pcscd's socket, which GnuPG and `ykman` reach the smart card interface through, and the
security keys' `/dev/hidraw*` devices, which `ykman` and libfido2's tools reach the FIDO2 and OTP
interfaces through, belong to the group `users`.

The regular account reads the state of the system (`systemctl status`, `systemctl --failed`) but
cannot change it: without polkit, only root changes anything through D-Bus, so `poweroff`, `reboot`
and `systemctl restart` fail with `Access denied`. (systemd's own `poweroff`, `reboot` and `halt`
fail without a word, so the account's `~/.profile` makes them aliases of `systemctl poweroff`,
`reboot` and `halt`, which say why.) To power the machine off, `exit` and log in as `root`.

The issue that `agetty` prints before the login prompt (which names the regular account: the build
replaces `$LFS_USER` in the profile's files), the message of the day that `login` prints after it,
the shell profile (`/etc/profile`), the regular account's own (`~/.profile`, which the build puts
under `/home/$LFS_USER`) and the udev rules that give the group `users` the security keys and USB
sticks are files of [`pi0-pgp/`](pi0-pgp). So is what only this system has: the key procedure
(`gpg-genkey` and the mount units of the stick and of GnuPG's memory),
scdaemon's configuration, and the drop-ins that give pcscd's socket its group and start the mounts
and `timesyncd`.


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

systemd mounts the stick on `/mnt/usb` the first time anything reads the directory, whoever it is,
and unmounts it when it has not been used for ten seconds: wait that long before pulling the stick
out. Without a stick, the access fails after ten seconds.

1. The Pi has no battery-backed clock. It restores the time it last saved, and a new image starts at
   the time it was made. Keys record the time they are made at, so set it:

   ```shell
   date -u -s '2026-10-19 08:30:00'
   ```

2. Make the key. The primary key only certifies; it has subkeys to sign, to encrypt and to
   authenticate, none of which expires. GnuPG's home is `/run/gnupg`, in memory (see [Keys in
   Memory](#keys-in-memory)), and the keys stay in it when the command ends. Give the passphrase
   through the environment, so that it stays out of the process list:

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

GnuPG's home, for the regular account, is `/run/gnupg`, which its `~/.profile` sets in `GNUPGHOME`:
in memory, so empty after a reboot (`gpg --import /mnt/usb/you@example.org-secret.asc` brings a key
back from the stick). root's is `~/.gnupg` on the SD card. `GPG_TTY=$(tty)` must be set when
GnuPG's input is not the terminal (`echo hi | gpg --clearsign`), for the PIN prompt to find it.


Keys in Memory
--------------

`gpg-genkey` keeps GnuPG's home, with the keyring, the agent's private keys, the random pool and
the revocation certificate, in `/run/gnupg`, a tmpfs that
[`run-gnupg.mount`](pi0-pgp/usr/lib/systemd/system/run-gnupg.mount) mounts at boot, and leaves it
there: `gpg` lists and edits the keys at any moment, until the Pi powers off.

* It is mounted `noswap`: the kernel never writes its pages to swap. A tmpfs without that option
  can, `/dev/shm` and `/run` included, if the kernel has swap: the guarantee does not depend on
  the kernel's configuration.
* Only the regular account opens it (mode 0700), nothing runs from it (`noexec`, `nosuid` and
  `nodev`), and it holds 8 MB at most.
* `gpg-genkey` refuses to start unless `/run/gnupg` is a tmpfs mounted `noswap`.
* The agent, which keeps the passphrase for ten minutes, quits when `gpg-genkey` ends, however it
  ends, and starts again when `gpg` needs it.
* Nothing deletes the keys: they go when the Pi powers off. Unmounting the tmpfs frees its pages,
  and the kernel zeroes every page that it frees (`init_on_free`, the capability
  [`zero-on-free`](../package/linux/zero-on-free.config)), which costs run time on every
  allocation.


Formatting the USB Stick
------------------------

The system makes the FAT file system that the stick needs, with `mkfs.fat` and `fatlabel` (from
`dosfstools`), and finds the stick with `blkid` (from `util-linux`), which lists the SD card's
partitions (`mmcblk0p1` and `mmcblk0p2`) too: the stick is `/dev/sda`, the first on the hub. The
regular account can format it: a udev rule
([`70-usb-sticks.rules`](pi0-pgp/usr/lib/udev/rules.d/70-usb-sticks.rules)) gives the block devices of
USB sticks to the group `users`, and leaves the SD card, which is not on USB, to root. This erases
the stick:

```shell
mkfs.fat -I -F 32 -n KEYS /dev/sda
```

The file system is FAT32, labelled `KEYS`, on the whole device (`-I` allows that). To make it on a
partition that the stick already has, name the partition (`/dev/sda1`) and leave `-I` out.
`fatlabel /dev/sda1 KEYS` gives the label to a file system that exists. The stick is ready at once:
systemd mounts it at the next access.

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
