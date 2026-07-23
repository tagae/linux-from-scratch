: ${package_version:=4.10.0}
: ${package_source:=https://ftp.gnu.org/gnu/findutils/findutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${localstatedir:+--localstatedir=$localstatedir}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
