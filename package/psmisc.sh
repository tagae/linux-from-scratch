: ${package_version:=23.7}
: ${package_source:=https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
