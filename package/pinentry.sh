: ${package_version:=1.3.2}
: ${package_source:=https://gnupg.org/ftp/gcrypt/pinentry/pinentry-$package_version.tar.bz2}
: ${package_source_hash:=sha256:8e986ed88561b4da6e9efe0c54fa4ca8923035c99264df0b0464497c5fb94e9e}

# Passphrase/PIN prompting for the gnupg family. Links against
# libgpg-error/libassuan, already installed into $INSTALL_DIR/$SYSTEM_KEY —
# see libassuan.sh for why target_sysroot_cc and the explicit --with-*-prefix
# flags are both needed.
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

prepare() {
    # pinentry-tty is the only variant with no target dependency — there's
    # no target ncurses (needed for -curses) or GUI toolkit (Qt/GTK/EFL/
    # tqt/FLTK) built for this project's targets.
    #
    # GPGRT_CONFIG: see libassuan.sh's prepare() for why this absolute
    # path (rather than relying on configure's own $PATH search) is
    # needed for every package here that probes libgpg-error this way.
    GPGRT_CONFIG=$INSTALL_DIR/$SYSTEM_KEY/usr/bin/gpgrt-config \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-doc \
        --enable-pinentry-tty \
        --disable-pinentry-curses \
        --disable-pinentry-qt \
        --disable-pinentry-qt5 \
        --disable-pinentry-gtk2 \
        --disable-pinentry-gnome3 \
        --disable-pinentry-tqt \
        --disable-pinentry-fltk \
        --with-libgpg-error-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr \
        --with-libassuan-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
