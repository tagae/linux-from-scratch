: ${package_version:=2.6.4}
: ${package_source:=https://github.com/westes/flex/releases/download/v$package_version/flex-$package_version.tar.gz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
