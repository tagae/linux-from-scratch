# A Raspberry Pi Zero as an air-gapped computer for private, sensitive work (profile/pi0-pgp.md):
# OpenPGP keys and YubiKeys, and USB sticks and drives. There is no network, no key server, and no
# X.509; the system keeps nothing across boots; and what goes in or out of it goes over USB or the
# serial console.
#
# The key's smart card interface is reached through pcscd (pcsc-lite with the CCID driver), started
# by systemd when a program connects to it, and its FIDO2 and OTP interfaces through hidraw.
# GnuPG's scdaemon reaches the key through pcscd as well, instead of through its own CCID driver
# over libusb (etc/gnupg/scdaemon.conf of the profile), so that gpg and ykman can share it.

lfs_system_toolchain glibc
# glibc loads libgcc_s to unwind stacks.
lfs_system_install gcc#runtime
# The locale of the shells (etc/profile), without whose UTF-8 tmux does not start.
lfs_system_install glibc#c-utf8

# Every package below that has completions for bash installs them, for bash-completion to load.
bash_completion=yes

#===[ Manual page tools ]===

# What makes manual pages from their sources: kmod's with scdoc, and shadow's, systemd's, D-Bus's
# and polkit's from DocBook, with xsltproc and DocBook's definitions and stylesheets.
lfs_tools_install scdoc
(
    # Where xsltproc finds the XML catalog (docbook-xsl's), in the tools rather than in the build
    # machine's /etc.
    sysconfdir=$LFS_TOOL_DIR/etc
    lfs_tools_install libxml2
)
lfs_tools_install libxslt
lfs_tools_install docbook-xml
lfs_tools_install docbook-xsl

#===[ systemd ]===

# systemd, with the strict minimum it needs to boot the system and log root in on the console: it
# mounts the file systems, and runs the services and the journal; and D-Bus, for its tools.

lfs_system_install dash

lfs_system_install kmod
lfs_sysroot_install kmod#dev
(
    # Strong hashes for new passwords, and glibc's for checking older ones.
    hashes=strong,glibc
    lfs_system_install libxcrypt
    lfs_sysroot_install libxcrypt#dev
)
lfs_system_install shadow

# The terminal library that procps' top and tmux link.
(
    shared=yes stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,tmux-256color,vt100,vt220,xterm,xterm-256color
    pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
    lfs_system_install ncurses
    lfs_sysroot_install ncurses#dev
)

# bash, root's shell, for the line editing, file completion and history that readline gives it; dash
# stays the system's sh, which scripts run in. Readline reads the terminal descriptions that ncurses
# holds.
(
    termcap_lib=ncursesw
    lfs_system_install bash
)

# bash-completion, with which Tab also completes what a command takes: options, units, the names of
# manual pages. etc/profile loads it.
lfs_system_install bash-completion

# util-linux: mount and umount, agetty and sulogin, which systemd and the key procedure run; libblkid
# and libmount, which systemd links; fdisk, sfdisk and cfdisk, which partition USB sticks and drives,
# with libfdisk, libsmartcols and libuuid under them; blkid, which tells what a device holds; dmesg,
# to read the kernel log; and more, which man shows the manual pages in.
(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    libblkid=yes libmount=yes libfdisk=yes libsmartcols=yes libuuid=yes
    fdisks=yes mount=yes blkid=yes agetty=yes sulogin=yes dmesg=yes more=yes
    lfs_system_install util-linux
    lfs_sysroot_install util-linux#dev
)

# libseccomp, which systemd links to filter the system calls of its units, as they ask for it.
lfs_system_install libseccomp
lfs_sysroot_install libseccomp#dev

(
    # timedatectl, with which the regular account sets the clock, as polkit lets it.
    timedated=yes
    lfs_system_install systemd
)
lfs_sysroot_install systemd#dev

# D-Bus, which systemctl, timedatectl, busctl and systemd-run reach systemd through (systemctl, for
# any user but root), started by its socket. There is no logind, and polkit (below) says what an
# account other than root changes through it. It reads its configuration with expat, and links
# systemd's libsystemd.
lfs_system_install expat
lfs_sysroot_install expat#dev
lfs_system_install dbus

#===[ Kernel and boot ]===

# The kernel, with the serial console, btrfs (the root file system's, and that of sticks and drives),
# ext4 and FAT file systems (sticks and drives), its self-protection, loadable modules, overlay file
# systems (memory over the read-only root), the options that systemd relies on, USB devices (YubiKeys,
# USB sticks, drives and card readers, also from user space through /dev/bus/usb), HID devices on USB
# as /dev/hidraw*, and the zeroing of memory as it is freed, which keeps secrets from outliving the
# programs that held them. The firmware's bootloader and configuration start it from the FAT partition
# of the Pi layout.
(
    capabilities="btrfs console ext4 fat hardening hidraw modules overlay serial-console systemd usb usb-storage zero-on-free"
    lfs_system_install linux
)
lfs_system_install firmware
# The root file system is read-only, so that the system keeps nothing of what is done on it: what is
# written to the home directories and to /var goes to memory, through the overlays of the profile
# (home.mount, root.mount, var.mount), and /tmp is systemd's tmpfs. The boot partition is not
# mounted. The clock, which the Pi has no battery for, starts every boot at the time the image was
# made.
(
    read_only_root=yes
    lfs_system_install boot
)

#===[ Libraries and tools ]===

# The compression library that GnuPG, libfido2 and Python link.
lfs_system_install zlib
lfs_sysroot_install zlib#dev

# The GNU tools for the console: the core utilities, find and xargs, grep, sed and gawk.
(
    # One program for all the utilities, which otherwise carry a copy of the same library each.
    single_binary=symlinks
    lfs_system_install coreutils
)
lfs_system_install findutils
lfs_system_install grep
lfs_system_install sed
lfs_system_install gawk

# man and info, which read the manual and Info pages that the packages install (the platform has
# `man=yes` and `info=yes`).
lfs_system_install mandoc
lfs_system_install texinfo
# The Linux man-pages: of the system calls, the C library, devices, file formats (the files of /etc
# among them) and glibc's commands, which the releases of Linux and glibc have none of.
lfs_system_install man-pages

(
    # Only libcrypto is wanted, which libfido2 and cryptography link: not the openssl program or the
    # legacy provider, nor the directories for certificates and configuration. The manual pages are
    # the library's.
    disable="apps legacy" ssldirs=no
    lfs_system_install openssl
    lfs_sysroot_install openssl#dev
)

#===[ FIDO2 security keys ]===

# libfido2's tools (fido2-token, fido2-cred and fido2-assert) drive the key's FIDO2 interface
# through /dev/hidraw*. libfido2 links systemd's libudev, and zlib.
lfs_system_install libcbor
lfs_sysroot_install libcbor#dev
lfs_system_install libfido2

#===[ GnuPG ]===

lfs_system_install libgpg-error
lfs_sysroot_install libgpg-error#dev

# Without udev, libusb finds the devices through sysfs. pcsc-lite and ccid below use it too.
lfs_system_install libusb
lfs_sysroot_install libusb#dev

(
    # The packages below look for libgpg-error with gpgrt-config, a script that runs on the build
    # machine and tells where the sysroot keeps it, instead of with the one they would find there.
    export GPGRT_CONFIG=$sysroot/usr/bin/gpgrt-config

    lfs_system_install libassuan
    lfs_sysroot_install libassuan#dev
    lfs_system_install libgcrypt
    lfs_sysroot_install libgcrypt#dev
    lfs_system_install libksba
    lfs_sysroot_install libksba#dev
    lfs_system_install npth
    lfs_sysroot_install npth#dev

    (
        # Only gpg, gpg-agent and scdaemon, with nothing that reaches the network or handles X.509
        # certificates. The CCID driver is required, so that a missing libusb is an error.
        sysconfdir=/etc
        ccid_driver=yes
        lfs_system_install gnupg
    )

    (
        # Asks for passphrases and PINs on the terminal.
        pinentry_tty=yes
        lfs_system_install pinentry
    )
)

#===[ USB storage ]===

# util-linux's fdisk, sfdisk and cfdisk (above) partition sticks and drives. mkfs.fat, mkfs.ext4
# and mkfs.btrfs make their file systems, which fsck.fat, e2fsck and `btrfs check` check; fatlabel,
# e2label and `btrfs filesystem label` name them. dd, of the core utilities, copies devices. The
# programs of e2fsprogs and btrfs-progs link util-linux's libuuid and libblkid.
lfs_system_install dosfstools
lfs_system_install e2fsprogs
lfs_system_install btrfs-progs

# The sticks' mount points (mnt-keys.mount, for the keys, and mnt-usb\x2dstorage.mount), which
# systemd cannot make on the read-only root.
mkdir -pv $system_dir/mnt/keys $system_dir/mnt/usb-storage

#===[ Processes and memory ]===

# ps, top, free, pgrep and the like, from procps-ng. top links ncurses; kill is dash's built-in.
lfs_system_install procps-ng

#===[ Terminal multiplexer ]===

# tmux, which runs several shells on the one serial console, and keeps them running while it is
# detached from. It links ncurses, and libevent for its event loop.
lfs_system_install libevent
lfs_sysroot_install libevent#dev
(
    # What runs in tmux meets this terminal, whose description ncurses holds (above).
    default_term=tmux-256color
    lfs_system_install tmux
)

#===[ Time zones ]===

# The time zone database, for the image's LFS_TIMEZONE and for programs that show local times.
# Without it, a system keeps UTC.
lfs_system_install tzdata

#===[ YubiKey Manager ]===

# ykman is a Python program: it needs ctypes, which needs libffi, cryptography, and pyscard for
# pcscd, besides pure Python libraries. pcscd links systemd's libraries and is started by its
# socket, as its own account, which ccid's udev rules give the readers to; Python links zlib.
lfs_system_install pcsc-lite
lfs_sysroot_install pcsc-lite#dev
lfs_system_install ccid

lfs_system_install libffi
lfs_sysroot_install libffi#dev
(
    # The kernel lacks IPv6.
    ipv6=no
    lfs_system_install python
    lfs_sysroot_install python#dev
)

# cryptography is Rust, which a prebuilt Rust toolchain compiles, and C code that cffi generates on
# the build machine, whose Python then needs cffi, and libffi under it.
lfs_tools_install rust
lfs_tools_install libffi
lfs_tools_install libffi#dev
lfs_tools_install python/setuptools
lfs_tools_install python/pycparser
lfs_tools_install python/cffi

# pyscard's code for PC/SC is generated by SWIG.
lfs_tools_install swig

lfs_system_install python/pycparser
lfs_system_install python/cffi
lfs_system_install python/cryptography

lfs_system_install python/pyscard

# What ykman imports. Left out are the libraries of keyring's backend for a secret service over
# D-Bus, which the systems have none of: keyring has no backend, and ykman then reports that it
# cannot remember a password. The packages carry no metadata, in which keyring would look for backends.
lfs_system_install python/six
lfs_system_install python/dateutil
lfs_system_install python/pskc
lfs_system_install python/click
lfs_system_install python/more-itertools
lfs_system_install python/jaraco-classes
lfs_system_install python/jaraco-context
lfs_system_install python/jaraco-functools
lfs_system_install python/keyring
lfs_system_install python/fido2
lfs_system_install python/yubikey-manager

#===[ Polkit ]===

# polkit, which systemd and timedated ask over D-Bus whether an account may power the machine off
# or set the clock, and whose rules (etc/polkit-1/rules.d of the profile) answer. It needs GLib,
# which needs PCRE2 (and libffi and libmount above), and runs its rules in JavaScript, with
# duktape. GLib's code generators run on the build machine, besides its libraries on the Zero.
lfs_tools_install pcre2
lfs_tools_install pcre2#dev
lfs_tools_install glib
lfs_tools_install glib#dev

lfs_system_install pcre2
lfs_sysroot_install pcre2#dev
lfs_system_install glib
lfs_sysroot_install glib#dev
lfs_system_install duktape
lfs_sysroot_install duktape#dev
lfs_sysroot_install dbus#dev
lfs_system_install polkit

#===[ Accounts ]===

# root logs in with bash, and with no password unless LFS_ROOT_PASSWORD sets one.
( root_shell=/bin/bash; lfs_system_set_root )

# A regular account besides root, for working with keys and USB storage without administrative
# rights: LFS_USER, of the group `users`, with bash for shell. Its group reaches the security keys'
# hidraw devices and the devices of USB sticks and drives (the profile's udev rules), and the files
# of the sticks that mnt-keys.mount and mnt-usb\x2dstorage.mount mount.
(
    user_shell=/bin/bash
    lfs_system_add_user
)
