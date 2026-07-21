: ${package_version:=2.5.2}
: ${package_source:=https://download.savannah.gnu.org/releases/attr/attr-$package_version.tar.gz}
: ${package_source_hash:=sha256:39bf67452fa41d0948c2197601053f48b3d78a029389734332a6309a680c6c87}

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
