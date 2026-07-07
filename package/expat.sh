: ${package_version:=2.8.1}
: ${package_source:=https://prdownloads.sourceforge.net/expat/expat-$package_version.tar.xz}

: ${prefix:=/usr}
: ${xmlwf:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static \
        --with-xmlwf=$xmlwf
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
