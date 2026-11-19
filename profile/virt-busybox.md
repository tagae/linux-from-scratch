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
`/lib/ld-musl-<arch>.so.1`. Its `crypt(3)`, which `login` checks passwords with, has the SHA-512
hash of root's password, so the system has no libxcrypt.


Accounts
--------

The system has one account, `root`, with the password `root` and ash as its shell. The static
accounts are those of [`package/busybox/etc`](../package/busybox/etc).


Building and Booting
--------------------

```shell
make virt-busybox-system         # build the system
make virt-busybox-qemu           # boot the image in QEMU, on the terminal (interactive)
make virt-busybox-test           # check that the image boots, root logs in, and poweroff is clean
make docker-virt-busybox-test    # the same, building through Docker Compose
```

Log in as `root` on the console. `poweroff` stops the machine, and QEMU exits.


How It Boots
------------

The kernel mounts devtmpfs on `/dev` before it starts init (the `devtmpfs` capability), and starts
`/sbin/init`, which is BusyBox's. Init reads
[`/etc/inittab`](../package/busybox/etc/inittab):

* It mounts `proc`, `sysfs` and a `tmpfs` on `/run`, which the kernel does not mount.
* It keeps a `getty` on `hvc0`, the virtio console, which runs `login`, which starts ash.
* At `poweroff`, `halt` and `reboot`, which signal init, it unmounts the file systems, or remounts
  read-only those that are busy, such as the root file system.


Applets
-------

BusyBox is configured from `allnoconfig`: an applet is in the system because its category is in the
`applets` option of the `busybox` package in the profile. A category is a directory of BusyBox's
source, and its file, `package/busybox/<category>.config`, lists the applets of the category that
the system's kernel can serve and a bare system has a use for, with their options, and the applets
that it leaves out, with the kernel option that each would need, or the reason.
`package/busybox/base.config` has the options that every system gets. The profile names the
categories below, which makes some 210 applets:

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
| `modutils`      | `insmod`, `rmmod`, `lsmod`, `modprobe`, `depmod`, `modinfo`              |
| `networking`    | `hostname`, `ipcalc`                                                     |
| `procps`        | `ps`, `top`, `free`, `kill`, `pidof`, `uptime`, `fuser`...               |
| `shell`         | `ash` (which is `/bin/sh`), `cttyhack`                                   |
| `util-linux`    | `mount`, `umount`, `blkid`, `fdisk`, `dmesg`, `taskset`...               |

The categories with a file that the profile leaves out are `e2fsprogs` (the kernel has no ext file
systems), `runit` (init is BusyBox's, and starts no supervised services), `mailutils` (there is no
mail) and `klibc-utils` (there is no initial RAM disk).

Three categories have no file, as their applets need what the kernel lacks: `printutils` (printers
and sockets), `selinux` (libselinux) and `sysklogd` (`syslogd` takes its messages through a UNIX
socket, which the kernel has no support for).

Most of what the system leaves out needs a kernel option that no capability of the profile gives:

| Without            | Missing                                                                |
|--------------------|------------------------------------------------------------------------|
| Sockets (`NET`)    | `ip`, `ping`, `wget`, `telnet`... (all networking applets), `sendmail` |
| Terminals (`VT`)   | `openvt`, `chvt`, `loadkmap`, `setfont`, `showkey`, `vlock`...         |
| Pseudo-terminals   | `script`, `scriptreplay`                                               |
| Swap, loop devices | `swapon`, `swapoff`, `mkswap`, `losetup`, `mount -o loop`              |
| Namespaces         | `unshare`, `nsenter`                                                   |
| `/proc/sys`        | `sysctl`                                                               |
| A clock device     | `hwclock`, `rtcwake`                                                   |

The system keeps no utmp, so `who`, `w`, `users`, `last` and `wall` are left out too, and `hush`,
BusyBox's second shell, is not wanted.

An applet that needs such an option is added with a kernel capability for it (`package/linux/`) and
the applet in the file of its category, in the same change.
