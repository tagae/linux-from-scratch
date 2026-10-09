: ${package_version:=4.21.0}
: ${package_source:=https://ftp.gnu.org/gnu/libtasn1/libtasn1-$package_version.tar.gz}
: ${package_source_hash:=sha256:1d8a444a223cc5464240777346e125de51d8e6abf0b8bac742ac84609167dc87}
: ${package_description:=ASN.1 (DER) parsing library.}
: ${package_license:=LGPL-2.1-or-later AND GPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --disable-doc
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
