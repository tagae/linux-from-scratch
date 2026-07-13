: ${package_version:=4.2}
: ${package_source:=https://github.com/dosfstools/dosfstools/releases/download/v$package_version/dosfstools-$package_version.tar.gz}

# mkfs.fat, needed by `image build` to format the FAT boot partition of the
# Pi image layout (lib/image.sh — the `single` layout has no boot partition
# and never calls it). Build-host-native, build/test-time only like the
# other image tools (btrfs-progs/kpartx/util-linux), never shipped to the
# target. Standard autotools; fsck.fat/fatlabel come along but are unused.
prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
