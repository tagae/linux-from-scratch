: ${package_version:=6.3.0}
: ${package_source:=https://ftpmirror.gnu.org/gmp/gmp-$package_version.tar.xz}

: ${prefix:=/usr}
: ${cxx:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-cxx=$cxx \
        --disable-static \
        --docdir=/usr/share/doc/gmp-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
