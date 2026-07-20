: ${package_version:=3.12}
: ${package_source:=https://ftp.gnu.org/gnu/grep/grep-$package_version.tar.xz}
: ${package_source_sha256:=2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9}

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
