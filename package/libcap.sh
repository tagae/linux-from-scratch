: ${package_version:=2.78}
: ${package_source:=https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-$package_version.tar.xz}

: ${prefix:=/usr}

build() {
    make -C $package_source_dir/libcap \
        CROSS_COMPILE=$target- \
        BUILD_CC=gcc \
        prefix=$prefix \
        lib=lib
}

install() {
    make -C $package_source_dir/libcap \
        CROSS_COMPILE=$target- \
        BUILD_CC=gcc \
        prefix=$prefix \
        lib=lib \
        DESTDIR=$package_install_dir \
        install
    rm -fv $package_install_dir/$prefix/lib/libcap.a
}
