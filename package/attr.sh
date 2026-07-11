: ${package_version:=2.5.2}
: ${package_source:=https://download.savannah.gnu.org/releases/attr/attr-$package_version.tar.gz}

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
