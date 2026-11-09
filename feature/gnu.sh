# The tools of the GNU userland, chapter 8 of the book: the shell, the core utilities, the tools to
# manage users, disks, logs and processes, the readers of man and info pages, and the time zone
# data. systemd builds on them.

lfs_system_install tzdata

( manpages=no; lfs_system_install kmod )
lfs_install_package kmod#dev
( bash_malloc=no; lfs_system_install bash )
(
    # One program for all the utilities, which otherwise carry a copy of the same library each.
    single_binary=symlinks
    install_program=hostname
    lfs_system_install coreutils
)
lfs_system_install grep
lfs_system_install sed
lfs_system_install gawk
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
    shared=yes normal=no debug=no ada=no cxx_binding=no stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color db_install=no
    pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
    lfs_system_install ncurses
    lfs_install_package ncurses#dev
)
# util-linux provides kill.
( kill=no; lfs_system_install procps-ng )
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

# The readers of man and info pages. They come after the packages above, which would otherwise pick
# up zlib, that mandoc requires, and configure differently.
lfs_system_install zlib
lfs_install_package zlib#dev
lfs_system_install mandoc
lfs_system_install texinfo
