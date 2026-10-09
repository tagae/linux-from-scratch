: ${package_version:=1.4.1}
: ${package_source:=https://ftp.gnu.org/gnu/mpc/mpc-$package_version.tar.xz}
: ${package_source_hash:=sha256:91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931}
: ${package_description:=GNU multiple-precision complex arithmetic library.}
: ${package_license:=LGPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${host:+--with-sysroot=$INSTALL_DIR/$SYSTEM_KEY} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
