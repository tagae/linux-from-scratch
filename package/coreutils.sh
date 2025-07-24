: ${package_version:=9.7}
: ${package_source:=https://ftp.gnu.org/gnu/coreutils/coreutils-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}
    : ${target:=$host}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --target=$target
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
