: ${package_version:=1.37.0}
: ${package_source:=https://busybox.net/downloads/busybox-$package_version.tar.bz2}

: ${prefix:=/usr}

prepare() {
    cd $package_source_dir
    make ARCH=$ARCH CROSS_COMPILE=$target- defconfig
    sed -i 's|.*CONFIG_STATIC.*|CONFIG_STATIC=y|' .config
    make ARCH=$ARCH CROSS_COMPILE=$target- CFLAGS="-I$TOOL_DIR/usr/include"
}

build() {
    cd $package_source_dir
    set -x
    make ARCH=$ARCH CROSS_COMPILE=$target- CONFIG_PREFIX=$LFS/usr install
}
