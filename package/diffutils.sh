: ${package_version:=3.12}
: ${package_source:=https://ftp.gnu.org/gnu/diffutils/diffutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd}
: ${package_description:=GNU file comparison utilities.}
: ${package_license:=GPL-3.0-or-later}

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
