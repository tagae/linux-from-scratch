: ${package_version:=1.4.21}
: ${package_source:=https://ftp.gnu.org/gnu/m4/m4-$package_version.tar.xz}

: ${prefix:=/usr}
: ${nls:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-nls=$nls
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
