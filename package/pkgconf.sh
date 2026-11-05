: ${package_version:=3.0.5}
: ${package_source:=https://distfiles.ariadne.space/pkgconf/pkgconf-$package_version.tar.xz}
: ${package_source_hash:=sha256:3acd3a8a3cce65a8d620321855d92fb602e026cbe8e13ee36bdec58483b59ace}
: ${package_description:=Compiler and linker flag helper for libraries (pkg-config).}
: ${package_license:=pkgconf}

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
