: ${package_version:=4.2.2}
: ${package_source:=https://ftp.gnu.org/gnu/mpfr/mpfr-$package_version.tar.xz}

: ${prefix:=/usr}
: ${thread_safe:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static \
        --enable-thread-safe=$thread_safe \
        --docdir=/usr/share/doc/mpfr-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
