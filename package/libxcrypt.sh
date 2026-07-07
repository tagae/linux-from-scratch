: ${package_version:=4.5.2}
: ${package_source:=https://github.com/besser82/libxcrypt/releases/download/v$package_version/libxcrypt-$package_version.tar.xz}

: ${prefix:=/usr}
: ${hashes:=strong,glibc}
: ${obsolete_api:=yes}
: ${failure_tokens:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-hashes=$hashes \
        --enable-obsolete-api=$obsolete_api \
        --disable-static \
        --enable-failure-tokens=$failure_tokens
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
