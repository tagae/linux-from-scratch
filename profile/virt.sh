# A bare-bones virtual machine, to show that the system boots cleanly, that root logs in on the
# console, and that it powers off: systemd, with the strict minimum it needs to boot the system and
# log root in, dash, root's shell and /bin/sh, and the kernel. It links kmod, libxcrypt, and
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
(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    # What systemd links, libmount and libblkid under it, and runs: mount, and agetty and sulogin
    # for the console.
    libblkid=yes libmount=yes mount=yes agetty=yes sulogin=yes
    lfs_system_install util-linux
    lfs_install_package util-linux#dev
)
lfs_system_install systemd

# The kernel, with a console (virtio's hvc0, from the platform's layer), the btrfs root file system, its
# self-protection and the options that systemd relies on.
( capabilities="btrfs console hardening systemd"; lfs_system_install linux )
