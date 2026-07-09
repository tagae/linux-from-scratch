: ${package_version:=1.4.1}
: ${package_source:=https://ftpmirror.gnu.org/mpc/mpc-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static \
        --docdir=/usr/share/doc/mpc-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
