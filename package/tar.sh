: ${package_version:=1.35}
: ${package_source:=https://ftp.gnu.org/gnu/tar/tar-$package_version.tar.xz}
: ${package_source_sha256:=4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
