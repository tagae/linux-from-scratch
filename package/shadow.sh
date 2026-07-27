: ${package_version:=4.19.4}
: ${package_source:=https://github.com/shadow-maint/shadow/releases/download/$package_version/shadow-$package_version.tar.xz}
: ${package_source_hash:=sha256:ce57a313e315a0a7cb04a8f50cc20753e994e487bbe9b78a2a824ca75cb486c0}

# build=: see gmp.sh's copy of this guard. target_sysroot_cc: login/passwd
# link the target tree's own libxcrypt (installed just before this by
# bootable-systemd-coreutils.sh) — same opt-in the gnupg family carries.
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

# --with-libbsd probes libbsd-overlay via pkg-config; point it at the
# TARGET tree's .pc files (see the cross pkg-config LIBDIR gotcha and
# python.sh's identical block — LIBDIR replaces the default search path,
# _SYSROOT_DIR rewrites the .pc's own recorded absolute paths). Guarded
# on host==target: a no-op wherever host stays unset.
if [ "${host:-}" = "$target" ]; then
    export PKG_CONFIG_LIBDIR=$INSTALL_DIR/$SYSTEM_KEY/usr/lib/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$INSTALL_DIR/$SYSTEM_KEY
fi

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --sysconfdir=/etc \
        --libdir=${prefix:-/usr}/lib \
        ${host:+--with-sysroot=$INSTALL_DIR/$SYSTEM_KEY} \
        --disable-static \
        --disable-logind \
        ${bcrypt:+--with-bcrypt=$bcrypt} \
        ${ycrypt:+--with-ycrypt=$ycrypt} \
        ${libbsd:+--with-libbsd=$libbsd} \
        ${audit:+--with-audit=$audit} \
        ${selinux:+--with-selinux=$selinux} \
        ${acl:+--with-acl=$acl} \
        ${attr:+--with-attr=$attr} \
        ${skey:+--with-skey=$skey} \
        ${tcpwrappers:+--with-tcpwrappers=$tcpwrappers}
}

build() {
    make
}

install() {
    # Reproduce system-files' merged-usr layout in this stage BEFORE make
    # install (same trick and reasoning as busybox.sh): shadow's own
    # Makefiles write the classic split-usr /sbin and /lib, which — staged
    # as REAL directories — would clobber the merged tree's sbin/lib
    # symlinks on merge (tar replaces a symlink with a directory), leaving
    # the kernel's /sbin/init lookup dangling (confirmed empirically:
    # "Kernel panic - not syncing: No working init found").
    mkdir -p $package_install_dir/usr/bin $package_install_dir/usr/sbin $package_install_dir/usr/lib
    ln -sfn usr/bin $package_install_dir/bin
    ln -sfn usr/sbin $package_install_dir/sbin
    ln -sfn usr/lib $package_install_dir/lib

    make install DESTDIR=$package_install_dir

    # Make passwd and newgrp suid
    chmod -v u+s $package_install_dir/usr/bin/passwd

    # Remove su (use util-linux's su instead)
    rm -fv $package_install_dir/usr/bin/su

    # Create /etc/shadow and /etc/gshadow with proper permissions
    touch $package_install_dir/etc/shadow $package_install_dir/etc/gshadow
    chmod 640 $package_install_dir/etc/shadow $package_install_dir/etc/gshadow
}
