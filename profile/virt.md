The `virt` Profile
==================

A QEMU virtual machine (platform `virt`) with the strict minimum that a systemd system needs to boot
and to log root in on its console. It is the default profile, and is defined in
[`virt.sh`](virt.sh).

It shows that the framework produces a system that boots cleanly, logs root in, and powers off:
`make test` boots it, and so does CI.


What the System Holds
---------------------

| Package      | What it is for                                                                        |
|--------------|---------------------------------------------------------------------------------------|
| `systemd`    | Init, with the journal in memory                                                      |
| `dbus`       | The system bus, which `busctl` and `systemd-run --wait` reach systemd through         |
| `expat`      | The XML parser that D-Bus reads its configuration with                                |
| `util-linux` | `mount`, `agetty` and `sulogin`, and the `libmount` and `libblkid` that systemd links |
| `shadow`     | `login`, which checks the password and starts root's shell                            |
| `libxcrypt`  | `crypt(3)`, with strong hashes for new passwords and glibc's for older ones           |
| `kmod`       | The module tools, which systemd links                                                 |
| `dash`       | `/bin/sh`, in which scripts run                                                       |
| `bash`       | Root's shell, with readline for line editing, file completion and history             |
| `ncurses`    | The terminal library that readline reads the terminal descriptions from               |
| `linux`      | The kernel                                                                            |

The descriptions of ncurses are those of `dumb`, `linux`, `vt100`, `vt220`, `xterm` and
`xterm-256color`, built into the library, instead of a database of every known terminal.

There is no network, no PAM, no polkit, no `logind`, and no documentation. The account database is
static.


Accounts
--------

The system has one account, `root`, with no password unless `LFS_ROOT_PASSWORD` sets one, and bash
as its shell. The static accounts, root's, locked, and those of systemd's services, are those of
[`package/systemd/etc`](../package/systemd/etc): the build sets root's password, or empties it, and
its shell.

The system's own files are those of [`virt/files/`](virt/files):

* `etc/issue`, which `agetty` prints before the login prompt.
* `etc/motd`, which `login` prints after a login: without PAM, `login` prints the file that
  `MOTD_FILE` names in `login.defs`, which is `/etc/motd`.
* `etc/profile`, which the shell of a login reads. The prompt is `user@host:directory`, ended by `#`
  for root. The history of the session is kept in memory only.


Building and Booting
--------------------

```shell
make virt-system         # build the system
make virt-qemu           # boot the image in QEMU, on the terminal (interactive)
make virt-test           # check that the image boots, root logs in, and poweroff is clean
make docker-virt-test    # the same, building through Docker Compose
```

`virt` is the default profile, so `make test` and `make docker-test` do the same.

Log in as `root` on the console. `poweroff` stops the machine, and QEMU exits. QEMU is given the
build machine's architecture, so that it can run the guest with an accelerator (HVF on macOS, KVM on
Linux), with one CPU and 512 MiB of memory.

Devices that the profile does not bring, such as a USB stick, are added with `LFS_QEMU_EXTRA`. The
machine has the controller (xHCI) for USB devices, but the kernel of this profile has no driver for
them.


How It Boots
------------

QEMU loads the kernel directly, so there is no boot loader and no boot partition. The image has a
single btrfs partition, on a virtio disk, which the kernel mounts as its root (`root=/dev/vda1`).
The console is virtio's (`console=hvc0`).

The image bakes a machine ID, so that the first boot is an ordinary one. systemd then starts as
init. No preset runs, and nothing enables `systemd-timesyncd`, which the recipe builds.

systemd's getty generator starts `agetty` on the console. `agetty` runs `login`, which asks for the
password and starts bash.

A qcow2 overlay (`image/virt.qcow2`) takes what the system writes, so that the image stays as it was
made. The overlay lasts until the image is made anew. `reboot` stops QEMU, as with `poweroff`
(QEMU runs with `-no-reboot`).


Kernel
------

The kernel is configured from `allnoconfig`, the layers that every system gets, and the
capabilities that the profile names, in `package/linux/`:

| Capability  | What it gives                                                                  |
|-------------|--------------------------------------------------------------------------------|
| `btrfs`     | The root file system that images are made with                                 |
| `console`   | The terminal layer that the console builds on                                  |
| `hardening` | Self-protection, with the options that the architecture and the kernel add     |
| `systemd`   | What systemd relies on: cgroups, namespaces, Unix sockets, BPF, `autofs`...    |

The platform's layer (`virt.config`) adds PCI Express, the virtio framework, the block device, the
console (`hvc0`) and the random number generator (`virtio-rng`).
