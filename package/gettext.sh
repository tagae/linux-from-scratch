: ${package_version:=1.0}
: ${package_source:=https://ftp.gnu.org/gnu/gettext/gettext-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --disable-shared \
        --docdir=/usr/share/doc/gettext-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
