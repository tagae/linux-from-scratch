: ${package_version:=1.61}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-$package_version.tar.bz2}
: ${package_source_hash:=sha256:7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93}
: ${package_description:=Error codes and common code of the GnuPG components.}
: ${package_license:=LGPL-2.1-or-later}

prepare() {
    case $package_component in
        libgpg-error)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                ${nls:+--enable-nls=$nls} \
                ${languages:+--enable-languages=$languages} \
                --disable-static \
                --disable-tests \
                --disable-doc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libgpg-error)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libgpg-error)
            make install DESTDIR=$package_install_dir
            # Its libtool archive makes libtool put the sysroot in the run-time path of the
            # libraries that link against it.
            rm -fv $package_install_dir$prefix/lib/libgpg-error.la
            # Plus the script that tells the flags for compiling against it.
            move_to_dev_component usr/bin/gpgrt-config
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
