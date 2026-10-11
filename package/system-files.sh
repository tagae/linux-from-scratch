: ${package_version:=0.1.0}
: ${package_description:=Base filesystem layout and system configuration files.}
: ${package_license:=MIT}

install() {
    cd $package_install_dir

    # Create the real directory tree under /usr
    mkdir -pv \
          usr/bin usr/sbin usr/lib usr/share \
          boot dev etc \
          proc root run sys tmp \
          var/log var/tmp

    # Compatibility symlinks (merged-usr layout: /bin, /sbin, /lib -> usr/*)
    # These must be created BEFORE any package installs to /bin, /sbin, /lib.
    ln -sfv usr/bin  bin
    ln -sfv usr/sbin sbin
    ln -sfv usr/lib  lib

    ln -sfv /proc/self/mounts etc/mtab
    ln -sfv /run var/run
    ln -sfv /run/lock var/lock

    # Content shared by every userland flavor (common/) plus whatever is
    # specific to this one ($USERLAND/, e.g. systemd's accounts). Flavor
    # content is copied second, so its etc/passwd, etc/shadow and etc/group
    # replace rather than merge with any common/ version.
    cp -rv $package_files_dir/common/* .
    cp -rv $package_files_dir/$USERLAND/* .

    chmod -v 0750 root
    chmod -v 1777 tmp var/tmp
    chmod -v 0600 etc/shadow

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
