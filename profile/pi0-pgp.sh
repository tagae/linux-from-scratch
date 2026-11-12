# A Raspberry Pi Zero to make OpenPGP keys offline, keep them on USB storage, and export them to a YubiKey.
#
# GnuPG makes a key in memory, and gpg-genkey backs it up to a USB stick; ykman, libfido2's tools
# and GnuPG itself configure and use the YubiKey's OpenPGP, PIV, FIDO2 and OTP applications. There
# is no network, no key server, and no X.509.
#
# The key's smart card interface is reached through pcscd (pcsc-lite with the CCID driver), started
# by systemd when a program connects to it, and its FIDO2 and OTP interfaces through hidraw.
# GnuPG's scdaemon reaches the key through pcscd as well, instead of through its own CCID driver
# over libusb, so that gpg and ykman can share it.

#===[ systemd ]===

# systemd, with the strict minimum it needs to boot the system and log root in on the console: it
# mounts the file systems, runs the services and the journal, and keeps the clock across boots.

lfs_system_install dash

( manpages=no; lfs_system_install kmod )
lfs_install_package kmod#dev
(
    # Strong hashes for new passwords, and glibc's for checking older ones.
    hashes=strong,glibc obsolete_api=no
    lfs_system_install libxcrypt
    lfs_install_package libxcrypt#dev
)
(
    # Root, the only account, needs no setuid programs.
    suidperms=0755 subordinate_ids=no
    lfs_system_install shadow
)

# The terminal library that procps' top links.
(
    shared=yes normal=no debug=no ada=no cxx_binding=no stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color db_install=no
    pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
    lfs_system_install ncurses
    lfs_install_package ncurses#dev
)

# util-linux: mount and umount, agetty and sulogin, which systemd and the key procedure run; libblkid
# and libmount, which systemd links; and dmesg, to read the kernel log.
(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    all_programs=no
    libblkid=yes libmount=yes
    mount=yes agetty=yes sulogin=yes dmesg=yes
    # libudev is systemd's, which it installs after.
    python=no systemd=no udev=no static=no
    makeinstall_chown=no makeinstall_setuid=no
    lfs_system_install util-linux
    lfs_install_package util-linux#dev
)

lfs_system_install systemd
lfs_install_package systemd#dev

#===[ Kernel and boot ]===

# The kernel, with its self-protection, the options that systemd relies on, USB devices (YubiKeys,
# USB sticks and card readers, also from user space through /dev/bus/usb), HID devices on USB as
# /dev/hidraw*, and FAT file systems on sticks. The firmware's bootloader and configuration start it from the FAT
# partition of the Pi layout.
( capabilities="hardening hidraw systemd usb usb-storage"; lfs_system_install linux )
lfs_system_install firmware
lfs_system_install boot

#===[ Libraries and tools ]===

# The compression library that GnuPG, libfido2 and Python link.
lfs_system_install zlib
lfs_install_package zlib#dev

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

(
    # Only libcrypto is wanted, which libfido2 and cryptography link: not the openssl program, its
    # documentation or the legacy provider, nor the directories for certificates and configuration.
    disable="apps docs legacy" ssldirs=no
    lfs_system_install openssl
    lfs_install_package openssl#dev
)

#===[ FIDO2 security keys ]===

# libfido2's tools (fido2-token, fido2-cred and fido2-assert) drive the key's FIDO2 interface
# through /dev/hidraw*. libfido2 links systemd's libudev, and zlib.
lfs_system_install libcbor
lfs_install_package libcbor#dev
lfs_system_install libfido2

#===[ GnuPG ]===

( languages=no; lfs_system_install libgpg-error )
lfs_install_package libgpg-error#dev

# Without udev, libusb finds the devices through sysfs. pcsc-lite and ccid below use it too.
( udev=no; lfs_system_install libusb )
lfs_install_package libusb#dev

(
    # The packages below look for libgpg-error with gpgrt-config, a script that runs on the build
    # machine and tells where the sysroot keeps it, instead of with the one they would find there.
    export GPGRT_CONFIG=$sysroot/usr/bin/gpgrt-config

    lfs_system_install libassuan
    lfs_install_package libassuan#dev
    lfs_system_install libgcrypt
    lfs_install_package libgcrypt#dev
    lfs_system_install libksba
    lfs_install_package libksba#dev
    lfs_system_install npth
    lfs_install_package npth#dev

    (
        # Only gpg, gpg-agent and scdaemon, with nothing that reaches the network or handles X.509
        # certificates. The CCID driver is required, so that a missing libusb is an error.
        sysconfdir=/etc
        gpgsm=no dirmngr=no keyboxd=no tpm2d=no wks_tools=no gpgtar=no
        tofu=no photo_viewers=no
        ccid_driver=yes
        lfs_system_install gnupg
    )

    (
        # Asks for passphrases and PINs on the terminal.
        pinentry_tty=yes
        pinentry_curses=no fallback_curses=no
        lfs_system_install pinentry
    )
)

# Makes a key in memory and exports it to a USB stick.
lfs_system_install gpg-genkey

#===[ Processes and memory ]===

# ps, top, free, pgrep and the like, from procps-ng. top links ncurses; kill is dash's built-in.
( kill=no; lfs_system_install procps-ng )

#===[ Time zones ]===

# The time zone database, for the image's TIMEZONE and for programs that show local times. Without
# it, a system keeps UTC.
lfs_system_install tzdata

#===[ YubiKey Manager ]===

# ykman is a Python program: it needs ctypes, which needs libffi, cryptography, and pyscard for
# pcscd, besides pure Python libraries. pcscd links systemd's libraries and is started by its
# socket, and Python links zlib.
lfs_system_install pcsc-lite
lfs_install_package pcsc-lite#dev
lfs_system_install ccid
lfs_system_install scdaemon-pcsc

lfs_system_install libffi
lfs_install_package libffi#dev
(
    # ykman and its libraries need neither pip, nor the test modules, nor IPv6, which the kernel
    # lacks.
    ensurepip=no test_modules=no ipv6=no
    lfs_system_install python
    lfs_install_package python#dev
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
# D-Bus, which the systems lack: keyring has no backend, and ykman then reports that it cannot
# remember a password. The packages carry no metadata, in which keyring would look for backends.
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
