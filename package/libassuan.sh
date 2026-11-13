: ${package_version:=3.0.2}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libassuan/libassuan-$package_version.tar.bz2}
: ${package_source_hash:=sha256:d2931cdad266e633510f9970e1a2f346055e351bb19f9b78912475b8074c36f6}
: ${package_description:=Inter-process communication of the GnuPG components.}
: ${package_license:=LGPL-2.1-or-later}

prepare() {
    case $package_component in
        libassuan)
            if docs_wanted; then doc=enable; else doc=disable; fi

            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                --disable-static \
                --$doc-doc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libassuan)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libassuan)
            make install DESTDIR=$package_install_dir
            # Plus the script that tells the flags for compiling against it.
            move_to_dev_component usr/bin/libassuan-config
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
