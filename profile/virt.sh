# A bare-bones virtual machine, to show that the system boots cleanly, that root logs in on the
# console, and that it powers off: systemd, with the strict minimum it needs to boot the system and
# log root in, dash, /bin/sh, bash, root's shell, and the kernel. It links kmod, libxcrypt, and
# util-linux's libmount and libblkid, and runs util-linux's mount, agetty and sulogin, and shadow's
# login, which starts root's shell. It brings the static accounts, root's included.

lfs_system_install dash

lfs_system_install kmod
lfs_install_package kmod#dev
(
    # Strong hashes for new passwords, and glibc's for checking older ones.
    hashes=strong,glibc
    lfs_system_install libxcrypt
    lfs_install_package libxcrypt#dev
)
lfs_system_install shadow

# The terminal library that bash's readline reads the terminal descriptions from.
(
    shared=yes stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color
    pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
    lfs_system_install ncurses
    lfs_install_package ncurses#dev
)

# bash, root's shell, for the line editing, file completion and history that readline gives it; dash
# stays the system's sh, which scripts run in. No bashbug, which mails bug reports.
(
    sh_link=no bashbug=no termcap_lib=ncursesw
    lfs_system_install bash
)

(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    # What systemd links, libmount and libblkid under it, and runs: mount, and agetty and sulogin
    # for the console.
    libblkid=yes libmount=yes mount=yes agetty=yes sulogin=yes
    lfs_system_install util-linux
    lfs_install_package util-linux#dev
)
(
    root_shell=/bin/bash
    lfs_system_install systemd
)

# The kernel, with a console (virtio's hvc0, from the platform's layer), the btrfs root file system, its
# self-protection and the options that systemd relies on.
( capabilities="btrfs console hardening systemd"; lfs_system_install linux )
