The `virt-busybox` Profile
==========================

A QEMU virtual machine (platform `virt`) that runs BusyBox as its init system, its shell and its
core utilities, in place of systemd, dash, bash and GNU coreutils, on musl in place of glibc. It is
defined in [`virt-busybox.sh`](virt-busybox.sh).

The system holds musl, BusyBox, and the kernel, which has a console, the btrfs root file system,
devtmpfs and hardening. There is no `dash`: `/bin/sh` is ash, BusyBox's shell.


musl
----

The profile starts with its cross toolchain, `lfs_system_toolchain musl`, which builds binutils, gcc
and musl for the triplet `<arch>-scratch-linux-musl`. musl's dynamic linker is the library itself,
`/lib/ld-musl-<arch>.so.1`. Its `crypt(3)`, which `login` checks passwords with, handles the SHA-512
hash of root's password, if it has one, so the system has no libxcrypt.


Accounts
--------

The system has one account, `root`, with no password unless `LFS_ROOT_PASSWORD` sets one, and ash as
its shell. The static accounts are those of [`package/busybox/etc`](../package/busybox/etc), where
root is locked: the build sets root's password, or empties it. root's prompt is in
[`virt-busybox/files/root/.profile`](virt-busybox/files/root/.profile), which ash reads when root
logs in. The system has neither an issue nor a message of the day.


Building and Booting
--------------------

```shell
make virt-busybox-system         # build the system
make virt-busybox-qemu           # boot the image in QEMU, on the terminal (interactive)
make virt-busybox-test           # check that the image boots, root logs in, and poweroff is clean
make docker-virt-busybox-test    # the same, building through Docker Compose
```

Log in as `root` on the console. `poweroff` stops the machine, and QEMU exits.

`make virt-busybox-test` runs the tests of [`virt-busybox/test/`](virt-busybox/test): the console;
BusyBox as init, `/bin/sh` and the applets of the profile, without those that the kernel cannot
serve; the file systems that init mounts, and what the system lacks (issue, message of the day,
module directory); the getty that init keeps on the console; a restart that keeps what was written;
and the power-off.


How It Boots
------------

The kernel mounts devtmpfs on `/dev` before it starts init (the `devtmpfs` capability), and starts
`/sbin/init`, which is BusyBox's. Init reads
[`/etc/inittab`](virt-busybox/files/etc/inittab), a file of the profile:

* It mounts `proc`, `sysfs` and a `tmpfs` on `/run`, which the kernel does not mount.
* It keeps a `getty` on `hvc0`, the virtio console, which runs `login`, which starts ash.
* At `poweroff`, `halt` and `reboot`, which signal init, it unmounts the file systems, or remounts
  read-only those that are busy, such as the root file system.


Applets
-------

BusyBox is configured from `allnoconfig`: an applet is in the system because its category is in the
`applets` option of the `busybox` package in the profile. A category is a directory of BusyBox's
source, and its file, `package/busybox/<category>.config`, lists the applets of the category that
the system's kernel can serve and a bare system has a use for, with their options.
`package/busybox/base.config` has the options that every system gets. The profile names the
categories below, which makes some 200 applets:

| Category        | Applets                                                                  |
|-----------------|--------------------------------------------------------------------------|
| `archival`      | `tar`, `gzip`, `bzip2`, `xz`, `unzip`, `cpio`, `ar`...                   |
| `console-tools` | `clear`, `reset`, `resize`                                               |
| `coreutils`     | `ls`, `cp`, `mv`, `rm`, `cat`, `sort`, `date`, `stat`, `sha256sum`...    |
| `debianutils`   | `which`, `start-stop-daemon`                                             |
| `editors`       | `vi`, `sed`, `awk`, `diff`, `cmp`, `patch`                               |
| `findutils`     | `find`, `grep`, `egrep`, `fgrep`, `xargs`                                |
| `init`          | `init`, `halt`, `poweroff`, `reboot`                                     |
| `loginutils`    | `getty`, `login`, `su`, `sulogin`, `passwd`, `adduser`, `deluser`...     |
| `miscutils`     | `less`, `bc`, `dc`, `time`, `strings`, `seedrng`...                      |
| `networking`    | `hostname`, `ipcalc`                                                     |
| `procps`        | `ps`, `top`, `free`, `kill`, `pidof`, `uptime`, `fuser`...               |
| `shell`         | `ash` (which is `/bin/sh`), `cttyhack`                                   |
| `util-linux`    | `mount`, `umount`, `blkid`, `fdisk`, `dmesg`, `taskset`...               |

An applet that needs a kernel option is added with a kernel capability for it (`package/linux/`)
and the applet in the file of its category, in the same change.
