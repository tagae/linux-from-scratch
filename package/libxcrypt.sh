: ${package_version:=4.5.2}
: ${package_source:=https://github.com/besser82/libxcrypt/releases/download/v$package_version/libxcrypt-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${hashes:+--enable-hashes=$hashes} \
        ${obsolete_api:+--enable-obsolete-api=$obsolete_api} \
        --disable-static \
        ${failure_tokens:+--enable-failure-tokens=$failure_tokens}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
