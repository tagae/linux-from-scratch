# A bare-bones virtual machine, to show that the system boots cleanly, that root logs in on the
# console, and that it powers off: systemd, with the strict minimum it needs to boot the system and
# log root in, dash, root's shell and /bin/sh, and the kernel. It links kmod, libxcrypt, and
# util-linux's libmount and libblkid, and runs util-linux's mount, agetty and sulogin, and shadow's
# login, which starts root's shell. It brings the static accounts, root's included.

lfs_system_install dash

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
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    # What systemd links, libmount and libblkid under it, and runs: mount, and agetty and sulogin
    # for the console.
    all_programs=no
    libblkid=yes libmount=yes mount=yes agetty=yes sulogin=yes
    python=no systemd=no static=no
    makeinstall_chown=no makeinstall_setuid=no
    lfs_system_install util-linux
    lfs_install_package util-linux#dev
)
lfs_system_install systemd

# The kernel, with its self-protection and the options that systemd relies on.
( capabilities="hardening systemd"; lfs_system_install linux )
