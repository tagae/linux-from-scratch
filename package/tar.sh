: ${package_version:=1.35}
: ${package_source:=https://ftp.gnu.org/gnu/tar/tar-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-nls
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
