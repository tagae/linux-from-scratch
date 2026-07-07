: ${package_version:=2.42.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/util-linux/v2.42/util-linux-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --bindir=/usr/bin \
        --libdir=/usr/lib \
        --sbindir=/usr/sbin \
        --disable-chfn-chsh \
        --disable-login \
        --disable-nologin \
        --disable-su \
        --disable-setpriv \
        --disable-runuser \
        --disable-pylibmount \
        --disable-static \
        --disable-liblastlog2 \
        --without-python \
        --without-systemd \
        --without-systemdsystemunitdir \
        --without-ncurses \
        --without-ncursesw \
        --without-tinfo \
        --disable-wall \
        --disable-makeinstall-chown \
        --docdir=/usr/share/doc/util-linux-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
