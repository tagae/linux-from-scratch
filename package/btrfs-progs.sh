: ${package_version:=6.17.1}
: ${package_source:=https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v$package_version.tar.xz}

package_source_dir=$SOURCE_DIR/btrfs-progs-v$package_version

# Only need mkfs.btrfs and the btrfs CLI (subvolume create) for image
# creation — disable everything else optional so we don't need zstd/lzo
# (compression backends), libudev (multipath support), python
# (libbtrfsutil bindings), or libext2fs/e2fsprogs (btrfs-convert, for
# converting an existing ext2/3/4 filesystem in place — we only ever
# format a fresh one).
# Hand-rolled configure/Makefile, not full autoconf — no out-of-tree build
# support, so run every step directly in package_source_dir.
prepare() {
    cd $package_source_dir
    ./configure \
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
