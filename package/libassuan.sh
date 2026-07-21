: ${package_version:=3.0.2}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libassuan/libassuan-$package_version.tar.bz2}
: ${package_source_hash:=sha256:d2931cdad266e633510f9970e1a2f346055e351bb19f9b78912475b8074c36f6}

# IPC between gpg, gpg-agent, scdaemon and pinentry (see GNUPG-YUBIKEY.md).
# Links against libgpg-error, already installed into $INSTALL_DIR/$PLATFORM
# — target_sysroot_cc (below) points the compiler at that tree's libc, and
# an explicit --with-libgpg-error-prefix (below) stops libassuan's own
# gpg-error-config probing from leaking a host or toolchain path instead.
# host/prefix/install-dir come from target_build_env; build= forces
# autoconf to treat a same-arch target (virt/pi4) as a cross build.
: ${build:=$(cc -dumpmachine)}
target_sysroot_cc

prepare() {
    # libgpg-error 1.51 only ships gpgrt-config (the newer pkg-config-style
    # multiplexer), not the legacy gpg-error-config wrapper this configure
    # otherwise falls back to. configure locates gpgrt-config via a plain
    # $PATH search (see its own "checking for gpgrt-config" step), which
    # never sees the sysroot — but an absolute GPGRT_CONFIG short-circuits
    # that search entirely (autoconf's own AC_PATH_PROG idiom: `case
    # $GPGRT_CONFIG in [\/]*) use it as-is`), and configure then derives
    # --libdir from GPGRT_CONFIG's own path, so gpgrt-config in turn finds
    # libgpg-error's .pc file with no separate PKG_CONFIG_LIBDIR needed.
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
