: ${package_version:=702}
: ${package_source:=https://www.greenwoodsoftware.com/less/less-$package_version.tar.gz}

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
