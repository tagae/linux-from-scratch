: ${package_version:=4.5.2}
: ${package_source:=https://github.com/besser82/libxcrypt/releases/download/v$package_version/libxcrypt-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-hashes=strong,glibc \
        --enable-obsolete-api=no \
        --disable-static \
        --disable-failure-tokens
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
