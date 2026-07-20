: ${package_version:=5.4.0}
: ${package_source:=https://ftp.gnu.org/gnu/gawk/gawk-$package_version.tar.xz}
: ${package_source_sha256:=3dd430f0cd3b4428c6c3f6afc021b9cd3c1f8c93f7a688dc268ca428a90b4ac1}

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
