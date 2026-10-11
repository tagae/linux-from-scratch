: ${package_version:=3.4.4}
: ${package_source:=https://download.samba.org/pub/rsync/src/rsync-$package_version.tar.gz}
: ${package_source_hash:=sha256:bd88cf82fa653da32314fb229136407c5c90f80d1758d8f4b091767877d8fa96}
: ${package_description:=Fast incremental file transfer.}
: ${package_license:=GPL-3.0-or-later}

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
