: ${package_version:=0.195}
: ${package_source:=https://sourceware.org/ftp/elfutils/$package_version/elfutils-$package_version.tar.bz2}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-debuginfod \
        --libdir=/usr/lib \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
