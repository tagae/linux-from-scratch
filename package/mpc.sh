: ${package_version:=1.4.1}
: ${package_source:=https://ftp.gnu.org/gnu/mpc/mpc-$package_version.tar.xz}
: ${package_source_hash:=sha256:91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931}

# build=: see gmp.sh's copy of this guard for why a target build (e.g. the
# guest-native gcc's own --with-mpc, see package/native-toolchain.sh)
# needs it. Deliberately `gcc`, not `cc` — see mpfr.sh's copy of this same
# guard for why (no "cc" binary exists anywhere in this project).
# target_sysroot_cc: links the target tree's own gmp/mpfr (installed there
# ahead of this by the same caller) — same trio the gnupg family already
# carries (see libassuan.sh).
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

prepare() {
    # --with-sysroot: see mpfr.sh's copy of this same flag — mpc links both
    # gmp and mpfr, so it hits libtool's own literal (un-sysroot-adjusted)
    # ".la libdir" resolution for both of them.
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
