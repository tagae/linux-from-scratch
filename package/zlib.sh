: ${package_version:=1.3.2}
: ${package_source:=https://zlib.net/zlib-$package_version.tar.xz}

prepare() {
    CC=$target-gcc AR=$target-ar RANLIB=$target-ranlib \
        $package_source_dir/configure ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    rm -fv $package_install_dir/$prefix/lib/libz.a
}
