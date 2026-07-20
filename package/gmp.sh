: ${package_version:=6.3.0}
: ${package_source:=https://ftpmirror.gnu.org/gmp/gmp-$package_version.tar.xz}
: ${package_source_sha256:=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898}

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
