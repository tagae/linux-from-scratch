: ${package_version:=5.8.3}
: ${package_source:=https://github.com/tukaani-project/xz/releases/download/v$package_version/xz-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${static:+--enable-static=$static} \
        --docdir=/usr/share/doc/xz-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
