: ${package_version:=3.3}
: ${package_source:=https://ftpmirror.gnu.org/gperf/gperf-$package_version.tar.gz}

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
