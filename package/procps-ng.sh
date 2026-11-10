: ${package_version:=4.0.7}
: ${package_source:=https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-$package_version.tar.xz}
: ${package_source_hash:=sha256:9d2021f47a4501c667862c9942a92d1953694b21d11bcd1702e83eb594e3d67d}
: ${package_description:=Utilities that report on processes and system resources.}
: ${package_license:=GPL-2.0-or-later AND LGPL-2.1-or-later}
: ${package_cpe:="a:procps-ng_project:procps-ng:$package_version a:procps_project:procps:$package_version"}

prepare() {
    case $package_component in
        procps-ng)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                ${nls:+--enable-nls=$nls} \
                ${kill:+--enable-kill=$kill} \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        procps-ng)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        procps-ng)
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
