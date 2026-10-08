: ${package_version:=1.3.2}
: ${package_source:=https://github.com/madler/zlib/releases/download/v$package_version/zlib-$package_version.tar.xz}
: ${package_source_hash:=sha256:d7a0654783a4da529d1bb793b7ad9c3318020af77667bcae35f95d0e42a792f3}

prepare() {
    $package_source_dir/configure ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    rm -fv $package_install_dir/$prefix/lib/libz.a
}
