: ${package_version:=1.12.4}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-$package_version.tar.bz2}
: ${package_source_hash:=sha256:d77f68f48879510e79a2f65977ccc68981781ea0923e5bdffac2a193ea3d660e}
: ${package_description:=Cryptographic library of GnuPG.}
: ${package_license:=LGPL-2.1-or-later AND BSD-3-Clause AND (CC0-1.0 OR Apache-2.0)}

prepare() {
    case $package_component in
        libgcrypt)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                --disable-static \
                --disable-doc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libgcrypt)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libgcrypt)
            make install DESTDIR=$package_install_dir
            # Plus the script that tells the flags for compiling against it.
            move_to_dev_component usr/bin/libgcrypt-config
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
