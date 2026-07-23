: ${package_version:=702}
: ${package_source:=https://www.greenwoodsoftware.com/less/less-$package_version.tar.gz}
: ${package_source_hash:=sha256:242a64c00f02d96f8ee208cf638ae1728b727c7f5fdf82a7d4f4cae32fb084e2}

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
