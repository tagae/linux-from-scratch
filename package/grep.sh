: ${package_version:=3.12}
: ${package_source:=https://ftp.gnu.org/gnu/grep/grep-$package_version.tar.xz}

: ${prefix:=/usr}
: ${nls:=no}

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
