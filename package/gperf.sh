: ${package_version:=3.3}
: ${package_source:=https://ftp.gnu.org/gnu/gperf/gperf-$package_version.tar.gz}
: ${package_source_hash:=sha256:fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8}

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
