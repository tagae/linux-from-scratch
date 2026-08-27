: ${package_version:=3.4.4}
: ${package_source:=https://download.samba.org/pub/rsync/rsync-$package_version.tar.gz}
: ${package_source_hash:=sha256:bd88cf82fa653da32314fb229136407c5c90f80d1758d8f4b091767877d8fa96}

# build=: see m4.sh's copy of this guard (the target build that ships this
# tool to the guest as an archive tarball). No target_sysroot_cc: this
# build already --disables every optional target library
# (openssl/xxhash/zstd/lz4) below, so rsync links nothing from the target
# tree either.
: ${build:=$(gcc -dumpmachine)}

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
