: ${package_version:=9.11}
: ${package_source:=https://ftp.gnu.org/gnu/coreutils/coreutils-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-no-install-program=kill,uptime
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
