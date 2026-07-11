: ${package_version:=2.5.1}
: ${package_source:=https://distfiles.ariadne.space/pkgconf/pkgconf-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --docdir=/usr/share/doc/pkgconf-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    ln -sfv pkgconf $package_install_dir/$prefix/bin/pkg-config
}
