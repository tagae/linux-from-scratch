: ${package_version:=6.17.1}
: ${package_source:=https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v$package_version.tar.xz}
: ${package_source_hash:=sha256:a4be0a6ebb3c476427fb5d97b2cf027b0ccdb6b0c55ff16323320c1e8cb77658}
: ${package_description:=Btrfs filesystem utilities and libraries.}
: ${package_license:=GPL-2.0-only AND LGPL-2.1-or-later}

package_source_dir=$SOURCE_DIR/btrfs-progs-v$package_version

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --disable-documentation \
        --disable-zstd \
        --disable-lzo \
        --disable-libudev \
        --disable-python \
        --disable-convert
}

build() {
    make -C $package_source_dir
}

install() {
    make -C $package_source_dir install DESTDIR=$package_install_dir
}
