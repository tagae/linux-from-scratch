# systemd, the init system and service manager, with the strict minimum it needs to boot the system
# and log root in on the console: it mounts the file systems, runs the services and the journal,
# and keeps the clock across boots. It links kmod, libxcrypt, and util-linux's libmount and
# libblkid, and runs util-linux's mount, agetty and sulogin, and shadow's login, which starts root's
# shell. It brings the static accounts, root's included.

# Requires: bash
# Linux: systemd

( manpages=no; lfs_system_install kmod )
lfs_install_package kmod#dev
(
    # Strong hashes for new passwords, and glibc's for checking older ones; nothing here needs the
    # interfaces of glibc's own libcrypt.
    hashes=strong,glibc obsolete_api=no
    lfs_system_install libxcrypt
    lfs_install_package libxcrypt#dev
)
(
    # Root, the only account, needs no setuid programs. Subordinate ids serve user namespaces, which
    # the kernels lack.
    suidperms=0755 subordinate_ids=no
    lfs_system_install shadow
)
(
    # util-linux's more, the pager of man and of systemd's tools, and cfdisk need it, and util-linux
    # is built once.
    shared=yes normal=no debug=no ada=no cxx_binding=no stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color db_install=no
    pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
    lfs_system_install ncurses
    lfs_install_package ncurses#dev
)
(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    # What systemd runs (agetty, fsck, mount, sulogin, swapon), and the basic tools to manage disks,
    # logs and processes.
    all_programs=no
    libblkid=yes libuuid=yes libmount=yes libsmartcols=yes libfdisk=yes
    mount=yes fsck=yes agetty=yes sulogin=yes swapon=yes
    blkid=yes lsblk=yes fdisks=yes losetup=yes dmesg=yes kill=yes more=yes
    python=no systemd=no static=no
    makeinstall_chown=no makeinstall_setuid=no
    lfs_system_install util-linux
    lfs_install_package util-linux#dev
)

lfs_system_install systemd
lfs_install_package systemd#dev
