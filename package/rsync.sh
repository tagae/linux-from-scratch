: ${package_version:=3.4.4}
: ${package_source:=https://download.samba.org/pub/rsync/rsync-$package_version.tar.gz}
: ${package_source_sha256:=bd88cf82fa653da32314fb229136407c5c90f80d1758d8f4b091767877d8fa96}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-md2man \
        --disable-openssl \
        --disable-xxhash \
        --disable-zstd \
        --disable-lz4
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
