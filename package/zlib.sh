: ${package_version:=1.3.2}
: ${package_source:=https://zlib.net/zlib-$package_version.tar.xz}

prepare() {
    # cross_target defaults to $target (the platform's real cross target),
    # but callers building this host-native (e.g. for the build host's own
    # wget, as opposed to a copy shipped to a target system) explicitly
    # pass cross_target="" for a plain "gcc"/"ar"/"ranlib". $target itself
    # is globally readonly and can't be reassigned even via a prefix
    # assignment, hence this separate var.
    : ${cross_target=$target}

    CC=${cross_target:+$cross_target-}gcc \
    AR=${cross_target:+$cross_target-}ar \
    RANLIB=${cross_target:+$cross_target-}ranlib \
        $package_source_dir/configure ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    rm -fv $package_install_dir/$prefix/lib/libz.a
}
