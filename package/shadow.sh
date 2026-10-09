: ${package_version:=4.19.4}
: ${package_source:=https://github.com/shadow-maint/shadow/releases/download/$package_version/shadow-$package_version.tar.xz}
: ${package_source_hash:=sha256:ce57a313e315a0a7cb04a8f50cc20753e994e487bbe9b78a2a824ca75cb486c0}

# build=: see gmp.sh's copy of this guard.
: ${build:=$(gcc -dumpmachine)}

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
    # install: shadow's own Makefiles write the classic split-usr /sbin and
    # /lib, which — staged as REAL directories — would clobber the merged
    # tree's sbin/lib symlinks on merge (tar replaces a symlink with a
    # directory), leaving the kernel's /sbin/init lookup dangling.
    mkdir -p $package_install_dir/usr/bin $package_install_dir/usr/sbin $package_install_dir/usr/lib
    ln -sfn usr/bin $package_install_dir/bin
    ln -sfn usr/sbin $package_install_dir/sbin
    ln -sfn usr/lib $package_install_dir/lib

    make install DESTDIR=$package_install_dir

    # Make passwd and newgrp suid
    chmod -v u+s $package_install_dir/usr/bin/passwd

    # Remove su (use util-linux's su instead)
    rm -fv $package_install_dir/usr/bin/su

    # Do NOT stage /etc/shadow or /etc/gshadow: system-files owns the
    # account database (root's password hash lives in ITS etc/shadow), and
    # under additive last-wins merge an empty file staged here would
    # clobber it — confirmed empirically: login silently rejected root
    # because the merged /etc/shadow was this recipe's 0-byte touch.
}
