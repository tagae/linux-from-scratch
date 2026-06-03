: ${package_version:=702}
: ${package_source:=https://www.greenwoodsoftware.com/less/less-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
