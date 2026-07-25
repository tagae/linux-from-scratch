# GNU libtasn1 — ASN.1 (DER) parsing library. p11-kit's trust module (native
# build-host tool) links it to read the anchor/certificate ASN.1 structures
# make-ca hands it; GnuTLS (target build, see package/gnutls.sh) links a
# second, target-built copy of this same script for the same reason.
: ${package_version:=4.21.0}
: ${package_source:=https://ftp.gnu.org/gnu/libtasn1/libtasn1-$package_version.tar.gz}
: ${package_source_hash:=sha256:1d8a444a223cc5464240777346e125de51d8e6abf0b8bac742ac84609167dc87}

# build=: see gmp.sh's copy of this guard for why a target build (unlike
# this script's original native/tools-phase use) needs it.
: ${build:=$(gcc -dumpmachine)}

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
