: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    # Create the real directory tree under /usr
    mkdir -pv \
          usr/bin usr/sbin usr/lib \
          usr/include usr/share \
          boot dev etc \
          proc root run sys tmp \
          var/log var/tmp \
          var/lfs

    # Compatibility symlinks (merged-usr layout: /bin, /sbin, /lib -> usr/*)
    # These must be created BEFORE any package installs to /bin, /sbin, /lib.
    ln -sfv usr/bin  bin
    ln -sfv usr/sbin sbin
    ln -sfv usr/lib  lib

    chmod -v 0750 root
    chmod -v 1777 tmp var/tmp

    ln -sfv /proc/self/mounts etc/mtab
    ln -sfv /run var/run
    ln -sfv /run/lock var/lock

    # Content shared by every userland flavor (common/) plus whatever is
    # specific to this one ($USERLAND/ — the systemd-* flavors ship their
    # dozen systemd-* accounts and messagebus/uuidd; busybox/ ships just
    # root + nobody). Flavor content is copied second so a same-named file
    # (etc/passwd, etc/shadow, etc/group) is fully replaced by the flavor's
    # own version rather than merged with common/ — those three differ too
    # much between flavors to split further, so they live entirely under
    # the per-flavor dirs and common/ only holds what is genuinely
    # identical (etc/hosts).
    cp -rv $package_files_dir/common/* .
    cp -rv $package_files_dir/$USERLAND/* .

    touch var/log/btmp var/log/lastlog var/log/faillog var/log/wtmp
    chgrp -v 13 var/log/lastlog 2>/dev/null || true  # 13 is utmp
    chmod -v 0664 var/log/lastlog
    chmod -v 0600 var/log/btmp

    cat > etc/lsb-release <<EOF
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="${LFS_RELEASE:-local}"
DISTRIB_CODENAME="${DISTRIB_CODENAME:-local}"
DISTRIB_DESCRIPTION="Linux From Scratch"
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
