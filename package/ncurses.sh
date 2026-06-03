: ${package_version:=6.6}
: ${package_source:=https://invisible-island.net/archives/ncurses/ncurses-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --with-shared \
        --without-debug \
        --without-normal \
        --with-cxx-shared \
        --enable-pc-files \
        --with-pkg-config-libdir=/usr/lib/pkgconfig \
        --enable-widec
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir

    for lib in ncurses form panel menu; do
        ln -sfv lib${lib}w.so $package_install_dir/$prefix/lib/lib${lib}.so
        ln -sfv ${lib}w.pc $package_install_dir/$prefix/lib/pkgconfig/${lib}.pc
    done
    ln -sfv libncursesw.so $package_install_dir/$prefix/lib/libcurses.so
}
