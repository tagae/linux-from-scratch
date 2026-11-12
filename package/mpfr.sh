: ${package_version:=4.2.2}
: ${package_source:=https://ftp.gnu.org/gnu/mpfr/mpfr-$package_version.tar.xz}
: ${package_source_hash:=sha256:b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01}
: ${package_description:=GNU multiple-precision floating-point library.}
: ${package_license:=LGPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${host:+--with-sysroot=$INSTALL_DIR/$PROFILE} \
        --disable-static \
        ${thread_safe:+--enable-thread-safe=$thread_safe}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
