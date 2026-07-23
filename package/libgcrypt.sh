: ${package_version:=1.12.0}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-$package_version.tar.bz2}
: ${package_source_hash:=sha256:0311454e678189bad62a7e9402a9dd793025efff6e7449898616e2fc75e0f4f5}

# Crypto primitives (see GNUPG-YUBIKEY.md). Links against libgpg-error —
# see libassuan.sh for why target_sysroot_cc and the explicit
# --with-libgpg-error-prefix are both needed.
: ${build:=$(cc -dumpmachine)}
target_sysroot_cc

prepare() {
    # GPGRT_CONFIG: see libassuan.sh's prepare() for why this absolute
    # path (rather than relying on configure's own $PATH search) is
    # needed for every package here that probes libgpg-error this way.
    GPGRT_CONFIG=$INSTALL_DIR/$PLATFORM/usr/bin/gpgrt-config \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-doc \
        --with-libgpg-error-prefix=$INSTALL_DIR/$PLATFORM/usr
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
