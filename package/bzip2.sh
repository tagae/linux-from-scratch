: ${package_version:=1.0.8}
: ${package_source:=https://sourceware.org/pub/bzip2/bzip2-$package_version.tar.gz}
: ${package_source_sha256:=ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269}

prepare() {
    # cross_target defaults to $target (the platform's real cross target),
    # but callers building this host-native (e.g. tar shelling out to it
    # to decompress .tar.bz2 sources, as opposed to a copy shipped to a
    # target system) explicitly pass cross_target="" for a plain "gcc"/
    # "ar"/"ranlib". $target itself is globally readonly and can't be
    # reassigned even via a prefix assignment, hence this separate var.
    : ${cross_target=$target}

    sed -i 's|/usr/local|$(PREFIX)|g' $package_source_dir/Makefile
}

build() {
    # Separate subshell from prepare() (see lib/package.sh's _install()) —
    # doesn't see prepare()'s own default, needs its own.
    : ${cross_target=$target}

    make -C $package_source_dir \
        CC=${cross_target:+$cross_target-}gcc \
        AR=${cross_target:+$cross_target-}ar \
        RANLIB=${cross_target:+$cross_target-}ranlib \
        -f Makefile-libbz2_so
    make -C $package_source_dir clean
    make -C $package_source_dir \
        CC=${cross_target:+$cross_target-}gcc \
        AR=${cross_target:+$cross_target-}ar \
        RANLIB=${cross_target:+$cross_target-}ranlib
}

install() {
    make -C $package_source_dir install PREFIX=$package_install_dir/$prefix
    cp -v $package_source_dir/libbz2.so.* $package_install_dir/$prefix/lib
    ln -sfv libbz2.so.1.0.8 $package_install_dir/$prefix/lib/libbz2.so.1.0
    ln -sfv libbz2.so.1.0 $package_install_dir/$prefix/lib/libbz2.so
    rm -fv $package_install_dir/$prefix/lib/libbz2.a
}
