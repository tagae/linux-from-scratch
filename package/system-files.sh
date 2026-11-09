: ${package_version:=0.1.0}
: ${package_description:=Base filesystem layout and system configuration files.}
: ${package_license:=MIT}

install() {
    cd $package_install_dir

    # Mount points, for the kernel's file systems and /tmp. Every other directory is created by
    # whatever puts something in it: a package, or systemd-tmpfiles at boot (/root, /var/log...).
    mkdir -pv dev proc run sys tmp

    # Compatibility symlinks (merged-usr layout: /bin, /sbin, /lib -> usr/*)
    # These must be created BEFORE any package installs to /bin, /sbin, /lib.
    ln -sfnv usr/bin  bin
    ln -sfnv usr/sbin sbin
    ln -sfnv usr/lib  lib
    # Where x86-64 programs load their dynamic linker from (/lib64/ld-linux-x86-64.so.2).
    ln -sfnv usr/lib  lib64

    mkdir -pv etc var
    ln -sfnv /proc/self/mounts etc/mtab
    ln -sfnv /run var/run
    ln -sfnv /run/lock var/lock

    # Configuration that every system has, whatever its init. The accounts come with the init.
    cp -rv $package_files_dir/etc .

    chmod -v 1777 tmp

    # File systems by the labels images give them. The Pi layout boots from a FAT partition, which
    # holds what the firmware loads.
    {
        echo "LABEL=base / btrfs defaults 0 0"
        [ "${IMAGE_LAYOUT:-pi}" = single ] || echo "LABEL=BOOT /boot vfat defaults 0 0"
    } > etc/fstab

    cat > etc/lsb-release <<EOF
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="${LFS_RELEASE:-local}"
DISTRIB_CODENAME="${DISTRIB_CODENAME:-local}"
DISTRIB_DESCRIPTION="${DISTRIB_DESCRIPTION:-Linux From Scratch}"
EOF

    cat > etc/os-release <<EOF
NAME="Linux From Scratch"
VERSION="${LFS_RELEASE:-local}"
ID=lfs
PRETTY_NAME="Linux From Scratch${LFS_RELEASE:+ $LFS_RELEASE}"
VERSION_CODENAME="${VERSION_CODENAME:-local}"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="${RELEASE_TYPE:-development}"
EOF

    if [ -n "${LFS_RELEASE:-}" ]; then
        echo "$LFS_RELEASE" > etc/lfs-release
    fi
}
