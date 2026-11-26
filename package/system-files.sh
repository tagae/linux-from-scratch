: ${package_version:=0.1.0}
: ${package_description:=Base filesystem layout and system configuration files.}
: ${package_license:=MIT}

install() {
    cd $package_install_dir

    # Mount points, for the kernel's file systems and /tmp. Every other directory is created by
    # whatever puts something in it: a package, or systemd-tmpfiles at boot (/root, /var/log...).
    mkdir -pv dev proc run sys tmp

    # The links of the merged-usr layout (/bin, /sbin, /lib -> usr/*), made before any package
    # installs there.
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

    cat > etc/lsb-release <<EOF
DISTRIB_ID="Linux From Scratch"
DISTRIB_CODENAME="${LFS_DISTRIB_CODENAME:-local}"
DISTRIB_DESCRIPTION="${LFS_DISTRIB_DESCRIPTION:-Linux From Scratch}"
EOF

    cat > etc/os-release <<EOF
NAME="Linux From Scratch"
ID=lfs
VERSION_CODENAME="${LFS_VERSION_CODENAME:-local}"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="${LFS_RELEASE_TYPE:-development}"
EOF
}
