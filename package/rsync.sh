: ${package_version:=3.4.4}
: ${package_source:=https://download.samba.org/pub/rsync/rsync-$package_version.tar.gz}

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
