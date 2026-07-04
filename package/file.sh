: ${package_version:=5.48}
: ${package_source:=https://astron.com/pub/file/file-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static \
        --enable-magic
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
