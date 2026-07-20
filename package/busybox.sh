: ${package_version:=1.37.0}
: ${package_source:=https://busybox.net/downloads/busybox-$package_version.tar.bz2}
: ${package_source_sha256:=3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4}

prepare() {
    make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- defconfig
    # Answer all new Kconfig prompts with defaults first
    yes "" | make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- oldconfig
    # Then apply our overrides so they are not overridden by oldconfig defaults
    sed -i \
        -e 's|^# CONFIG_STATIC is not set$|CONFIG_STATIC=y|' \
        -e 's|^CONFIG_STATIC=.*$|CONFIG_STATIC=y|' \
        -e 's|^CONFIG_TC=y|# CONFIG_TC is not set|' \
        -e 's|^CONFIG_SHA1_HWACCEL=y|# CONFIG_SHA1_HWACCEL is not set|' \
        -e 's|^CONFIG_SHA256_HWACCEL=y|# CONFIG_SHA256_HWACCEL is not set|' \
        $package_source_dir/.config
    make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- silentoldconfig </dev/null
}

build() {
    yes "" | make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target-
}

install() {
    make -C $package_source_dir \
        ARCH=$ARCH \
        CROSS_COMPILE=$target- \
        CONFIG_PREFIX=$package_install_dir \
        install
}
