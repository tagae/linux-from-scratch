: ${package_version:=4.4.1}
: ${package_source:=https://ftp.gnu.org/gnu/make/make-$package_version.tar.gz}

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
