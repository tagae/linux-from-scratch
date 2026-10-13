: ${package_version:=1.8.1}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libksba/libksba-$package_version.tar.bz2}
: ${package_source_hash:=sha256:c2f84393011827219ae117131dba8e7684c2bed0961eed11b0642c2acba440b5}
: ${package_description:=X.509 certificates and CMS library of GnuPG.}
: ${package_license:=LGPL-3.0-or-later OR GPL-2.0-or-later}

prepare() {
    case $package_component in
        libksba)
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
        libksba)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libksba)
            make install DESTDIR=$package_install_dir
            # Plus the script that tells the flags for compiling against it.
            move_to_dev_component usr/bin/ksba-config
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
