: ${package_version:=3.5.0}
: ${package_source:=https://download.samba.org/pub/rsync/src/rsync-$package_version.tar.gz}
: ${package_source_hash:=sha256:c7ffd1ef653e99540f661e47cb00b7f9cad1ee6b972399b16f93d672656e0d33}
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
