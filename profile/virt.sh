# A bare-bones virtual machine, to show that the system boots cleanly, that root logs in on the
# console, and that it powers off (profile/virt.md): systemd, with the strict minimum it needs to
# boot the system and log root in, D-Bus, dash, /bin/sh, bash, root's shell, and the kernel.

lfs_system_toolchain glibc
# glibc loads libgcc_s to unwind stacks.
lfs_system_install gcc#runtime

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

# The terminal library that bash's readline reads the terminal descriptions from.
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
# stays the system's sh, which scripts run in.
(
    termcap_lib=ncursesw
    lfs_system_install bash
)

(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    # What systemd links, libmount and libblkid under it, and runs: mount, and agetty and sulogin
    # for the console.
    libblkid=yes libmount=yes mount=yes agetty=yes sulogin=yes
    lfs_system_install util-linux
    lfs_sysroot_install util-linux#dev
)
# libseccomp, which systemd links to filter the system calls of its units, as they ask for it.
lfs_system_install libseccomp
lfs_sysroot_install libseccomp#dev

lfs_system_install systemd
lfs_sysroot_install systemd#dev

# D-Bus, which systemctl, busctl and systemd-run reach systemd through (systemctl, for any user but
# root), started by its socket. It reads its configuration with expat, and links systemd's
# libsystemd.
lfs_system_install expat
lfs_sysroot_install expat#dev
lfs_system_install dbus

# The kernel, with a console (virtio's hvc0, from the platform's layer), the btrfs root file system,
# its self-protection, loadable modules (systemd loads autofs4) and the options that systemd relies
# on.
( capabilities="btrfs console hardening modules systemd"; lfs_system_install linux )

# root logs in with bash, a shell with line editing, and with no password unless LFS_ROOT_PASSWORD
# sets one.
( root_shell=/bin/bash; lfs_system_set_root )
