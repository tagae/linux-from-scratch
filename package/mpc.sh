: ${package_version:=1.4.1}
: ${package_source:=https://ftpmirror.gnu.org/mpc/mpc-$package_version.tar.xz}
: ${package_source_sha256:=91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --docdir=/usr/share/doc/mpc-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
