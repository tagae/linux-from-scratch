: ${package_version:=3.5.2}
: ${package_source:=https://github.com/libffi/libffi/releases/download/v$package_version/libffi-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static \
        --with-gcc-arch=${arch:-native}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
