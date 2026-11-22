# A Raspberry Pi Zero to make OpenPGP keys offline, keep them on USB storage, and export them to a YubiKey.
#
# GnuPG makes a key in memory, and gpg-genkey backs it up to a USB stick; ykman, libfido2's tools
# and GnuPG itself configure and use the YubiKey's OpenPGP, PIV, FIDO2 and OTP applications. There
# is no network, no key server, and no X.509.
#
# The key's smart card interface is reached through pcscd (pcsc-lite with the CCID driver), started
# by systemd when a program connects to it, and its FIDO2 and OTP interfaces through hidraw.
# GnuPG's scdaemon reaches the key through pcscd as well, instead of through its own CCID driver
# over libusb (etc/gnupg/scdaemon.conf of the profile), so that gpg and ykman can share it.

lfs_system_toolchain glibc
# glibc loads libgcc_s to unwind stacks.
lfs_system_install gcc#runtime

#===[ systemd ]===

# systemd, with the strict minimum it needs to boot the system and log root in on the console: it
# mounts the file systems, runs the services and the journal, and keeps the clock across boots; and
# D-Bus, for its tools.

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

# The terminal library that procps' top links.
(
    shared=yes stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color
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

# util-linux: mount and umount, agetty and sulogin, which systemd and the key procedure run; libblkid
# and libmount, which systemd links; blkid, which finds the stick to format; dmesg, to read the
# kernel log; and more, which man shows the manual pages in.
(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    libblkid=yes libmount=yes
    mount=yes blkid=yes agetty=yes sulogin=yes dmesg=yes more=yes
    lfs_system_install util-linux
    lfs_sysroot_install util-linux#dev
)

lfs_system_install systemd
lfs_sysroot_install systemd#dev

# D-Bus, which systemctl, busctl and systemd-run reach systemd through (systemctl, for any user but
# root), started by its socket. There is no polkit or logind, so only root changes anything through
# it. It reads its configuration with expat, and links systemd's libsystemd.
lfs_system_install expat
lfs_sysroot_install expat#dev
lfs_system_install dbus

#===[ Kernel and boot ]===

# The kernel, with the serial console, the btrfs root file system, FAT file systems (the Pi layout's
# boot partition, and sticks), its self-protection, loadable modules, the options that systemd
# relies on, USB devices (YubiKeys, USB sticks and card readers, also from user space through
# /dev/bus/usb), and HID devices on USB as /dev/hidraw*. The firmware's bootloader and configuration
# start it from the FAT partition of the Pi layout.
(
    capabilities="btrfs console fat hardening hidraw modules serial-console systemd usb usb-storage"
    lfs_system_install linux
)
lfs_system_install firmware
lfs_system_install boot

#===[ Libraries and tools ]===

# The compression library that GnuPG, libfido2 and Python link.
lfs_system_install zlib
lfs_sysroot_install zlib#dev

# The GNU tools: the core utilities, grep and sed for the console, and gawk, which gpg-genkey, a shell
# script, runs.
(
    # One program for all the utilities, which otherwise carry a copy of the same library each.
    single_binary=symlinks
    lfs_system_install coreutils
)
lfs_system_install grep
lfs_system_install sed
lfs_system_install gawk

# man and info, which read the manual and Info pages that the packages install (the platform has
# `man=yes` and `info=yes`).
lfs_system_install mandoc
lfs_system_install texinfo

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

#===[ USB sticks ]===

# The key procedure's own script, gpg-genkey, makes a key in memory and exports it to a USB stick,
# which mnt-usb.automount mounts on /mnt/usb: they are files of the profile. mkfs.fat makes the FAT
# file system that the script wants on the stick, labelled KEYS (fatlabel changes the label of one
# that exists), and fsck.fat checks it.
lfs_system_install dosfstools

#===[ Processes and memory ]===

# ps, top, free, pgrep and the like, from procps-ng. top links ncurses; kill is dash's built-in.
lfs_system_install procps-ng

#===[ Time zones ]===

# The time zone database, for the image's LFS_TIMEZONE and for programs that show local times.
# Without it, a system keeps UTC.
lfs_system_install tzdata

#===[ YubiKey Manager ]===

# ykman is a Python program: it needs ctypes, which needs libffi, cryptography, and pyscard for
# pcscd, besides pure Python libraries. pcscd links systemd's libraries and is started by its
# socket, and Python links zlib.
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

#===[ Accounts ]===

# root logs in with bash, and with no password unless LFS_ROOT_PASSWORD sets one.
( root_shell=/bin/bash; lfs_system_set_root )

# A regular account besides root, for working with keys without administrative rights: LFS_USER, of
# the group `users`, with bash for shell. Its group reaches pcscd's socket, the security keys'
# hidraw devices and the devices of USB sticks (the profile's udev rules), and the files of the
# stick that mnt-usb.mount mounts (gpg-genkey).
(
    user_shell=/bin/bash
    lfs_system_add_user
)

#===[ Documentation ]===

# The index of the man pages, which man and apropos search, and the directory of the Info pages, which
# info starts from. They are made here, with mandoc and texinfo built for the build machine, as the
# system's cannot run on it. A page that has no entry for the directory is left out of it.
if [ "${man:-no}" = yes ]; then
    lfs_tools_install mandoc
    makewhatis $system_dir/usr/share/man
fi
if [ "${info:-no}" = yes ]; then
    lfs_tools_install texinfo
    for file in $system_dir/usr/share/info/*.info; do
        install-info --dir-file=$system_dir/usr/share/info/dir $file || :
    done
fi
