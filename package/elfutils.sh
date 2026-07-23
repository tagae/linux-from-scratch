: ${package_version:=0.195}
: ${package_source:=https://sourceware.org/ftp/elfutils/$package_version/elfutils-$package_version.tar.bz2}
: ${package_source_hash:=sha256:37629fdf7f1f3dc2818e138fca2b8094177d6c2d0f701d3bb650a561218dc026}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-debuginfod \
        --libdir=/usr/lib \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
