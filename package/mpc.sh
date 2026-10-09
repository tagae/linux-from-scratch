: ${package_version:=1.4.1}
: ${package_source:=https://ftp.gnu.org/gnu/mpc/mpc-$package_version.tar.xz}
: ${package_source_hash:=sha256:91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931}

prepare() {
    # --with-sysroot: mpc links both gmp and mpfr, so it hits libtool's own literal
    # (un-sysroot-adjusted) ".la libdir" resolution for both of them.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${host:+--with-sysroot=$INSTALL_DIR/$SYSTEM_KEY} \
        --disable-static \
        --docdir=${prefix:-/usr}/share/doc/mpc-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
