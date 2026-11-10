# util-linux's tools to manage disks, logs and processes: blkid, lsblk, fdisk, sfdisk, cfdisk,
# losetup, dmesg, kill, more, fsck and swapon. It builds util-linux again, over the minimal build
# that systemd brings, with systemd's programs and libraries among the others.

# Requires: ncurses

(
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
    all_programs=no
    libblkid=yes libuuid=yes libmount=yes libsmartcols=yes libfdisk=yes
    mount=yes fsck=yes agetty=yes sulogin=yes swapon=yes
    blkid=yes lsblk=yes fdisks=yes losetup=yes dmesg=yes kill=yes more=yes
    # libudev, which systemd installs before, is left out, as from systemd's own util-linux.
    python=no systemd=no udev=no static=no
    makeinstall_chown=no makeinstall_setuid=no
    lfs_system_install util-linux
    lfs_install_package util-linux#dev
)
