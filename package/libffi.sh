: ${package_version:=3.5.2}
: ${package_source:=https://github.com/libffi/libffi/releases/download/v$package_version/libffi-$package_version.tar.gz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        ${arch:+--with-gcc-arch=$arch}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
