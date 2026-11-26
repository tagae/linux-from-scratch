: ${package_version:=1.1.45}
: ${package_source:=https://download.gnome.org/sources/libxslt/${package_version%.*}/libxslt-$package_version.tar.xz}
: ${package_source_hash:=sha256:9acfe68419c4d06a45c550321b3212762d92f41465062ca4ea19e632ee5d216e}
: ${package_description:=XSLT processor (xsltproc).}
: ${package_license:=MIT}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --without-python
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    move_to_docs_component
}
