: ${package_version:=4.2.2}
: ${package_source:=https://ftpmirror.gnu.org/mpfr/mpfr-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        ${thread_safe:+--enable-thread-safe=$thread_safe} \
        --docdir=/usr/share/doc/mpfr-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
