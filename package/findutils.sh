: ${package_version:=4.10.0}
: ${package_source:=https://ftp.gnu.org/gnu/findutils/findutils-$package_version.tar.xz}

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
