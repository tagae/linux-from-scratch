: ${package_version:=6.3.0}
: ${package_source:=https://ftpmirror.gnu.org/gmp/gmp-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${cxx:+--enable-cxx=$cxx} \
        --disable-static \
        --docdir=/usr/share/doc/gmp-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
