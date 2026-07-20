: ${package_version:=1.14}
: ${package_source:=https://ftp.gnu.org/gnu/gzip/gzip-$package_version.tar.xz}
: ${package_source_sha256:=01a7b881bd220bfdf615f97b8718f80bdfd3f6add385b993dcf6efd14e8c0ac6}

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
