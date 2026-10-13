: ${package_version:=1.3.3}
: ${package_source:=https://gnupg.org/ftp/gcrypt/pinentry/pinentry-$package_version.tar.bz2}
: ${package_source_hash:=sha256:c2970f16d6afb66ecddfca767d743936c86239bff936eed7fd7597a678414b63}
: ${package_description:=Passphrase and PIN entry dialogs for GnuPG.}
: ${package_license:=GPL-2.0-or-later}

prepare() {
    case $package_component in
        pinentry)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${pinentry_tty:+--enable-pinentry-tty=$pinentry_tty} \
                ${pinentry_curses:+--enable-pinentry-curses=$pinentry_curses} \
                ${fallback_curses:+--enable-fallback-curses=$fallback_curses} \
                ${pinentry_gtk2:+--enable-pinentry-gtk2=$pinentry_gtk2} \
                ${pinentry_gnome3:+--enable-pinentry-gnome3=$pinentry_gnome3} \
                ${libsecret:+--enable-libsecret=$libsecret} \
                ${pinentry_qt5:+--enable-pinentry-qt5=$pinentry_qt5} \
                ${pinentry_qt:+--enable-pinentry-qt=$pinentry_qt} \
                ${pinentry_qt4:+--enable-pinentry-qt4=$pinentry_qt4} \
                ${pinentry_tqt:+--enable-pinentry-tqt=$pinentry_tqt} \
                ${pinentry_efl:+--enable-pinentry-efl=$pinentry_efl} \
                ${pinentry_fltk:+--enable-pinentry-fltk=$pinentry_fltk} \
                --disable-doc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        pinentry)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        pinentry)
            make install DESTDIR=$package_install_dir
            move_to_dev_component
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
