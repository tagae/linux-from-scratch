: ${package_version:=4.19.4}
: ${package_source:=https://github.com/shadow-maint/shadow/releases/download/$package_version/shadow-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --sysconfdir=/etc \
        --disable-static \
        --with-bcrypt \
        --with-ycrypt \
        --without-libbsd \
        --without-audit \
        --without-selinux \
        --without-acl \
        --without-attr \
        --without-skey \
        --without-tcpwrappers
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir

    # Make passwd and newgrp suid
    chmod -v u+s $package_install_dir/usr/bin/passwd

    # Remove su (use util-linux's su instead)
    rm -fv $package_install_dir/usr/bin/su

    # Create /etc/shadow and /etc/gshadow with proper permissions
    touch $package_install_dir/etc/shadow $package_install_dir/etc/gshadow
    chmod 640 $package_install_dir/etc/shadow $package_install_dir/etc/gshadow
}
