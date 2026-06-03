: ${package_version:=2.6.4}
: ${package_source:=https://github.com/westes/flex/releases/download/v$package_version/flex-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
