: ${package_version:=5.4.0}
: ${package_source:=https://ftp.gnu.org/gnu/gawk/gawk-$package_version.tar.xz}
: ${package_source_hash:=sha256:3dd430f0cd3b4428c6c3f6afc021b9cd3c1f8c93f7a688dc268ca428a90b4ac1}
: ${package_description:=GNU awk pattern scanning and processing language.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    case $package_component in
        gawk)
            # No dynamic extensions, nor the allocator for persistent memory.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                --sysconfdir=/etc \
                ${nls:+--enable-nls=$nls} \
                --disable-extensions \
                --disable-pma
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        gawk)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        gawk)
            make install DESTDIR=$package_install_dir
            # gawkbug mails bug reports, and the program with the version is a second name for gawk.
            rm -v $package_install_dir$prefix/bin/gawkbug \
                $package_install_dir$prefix/bin/gawk-$package_version
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
