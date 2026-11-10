: ${package_version:=1.8}
: ${package_source:=https://gnupg.org/ftp/gcrypt/npth/npth-$package_version.tar.bz2}
: ${package_source_hash:=sha256:8bd24b4f23a3065d6e5b26e98aba9ce783ea4fd781069c1b35d149694e90ca3e}
: ${package_description:=Non-preemptive threads library of GnuPG.}
: ${package_license:=LGPL-2.1-or-later}
: ${package_cpe:=none}

prepare() {
    case $package_component in
        npth)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                --disable-static \
                --disable-tests
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        npth)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        npth)
            make install DESTDIR=$package_install_dir
            move_to_dev_component
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
