: ${package_version:=2.8.1}
: ${package_source:=https://prdownloads.sourceforge.net/expat/expat-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        ${xmlwf:+--with-xmlwf=$xmlwf}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
