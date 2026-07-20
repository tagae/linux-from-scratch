: ${package_version:=2.78}
: ${package_source:=https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-$package_version.tar.xz}
: ${package_source_sha256:=0d621e562fd932ccf67b9660fb018e468a683d7b827541df27813228c996bb11}

build() {
    make -C $package_source_dir/libcap \
        CROSS_COMPILE=$target- \
        BUILD_CC=gcc \
        ${prefix:+prefix=$prefix} \
        lib=lib
}

install() {
    make -C $package_source_dir/libcap \
        CROSS_COMPILE=$target- \
        BUILD_CC=gcc \
        ${prefix:+prefix=$prefix} \
        lib=lib \
        DESTDIR=$package_install_dir \
        install
    rm -fv $package_install_dir/$prefix/lib/libcap.a
}
