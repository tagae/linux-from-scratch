: ${package_version:=1.0.30}
: ${package_source:=https://github.com/libusb/libusb/releases/download/v$package_version/libusb-$package_version.tar.bz2}
: ${package_source_hash:=sha256:fea36f34f9156400209595e300840767ab1a385ede1dc7ee893015aea9c6dbaf}
: ${package_description:=Library for talking to USB devices from user space.}
: ${package_license:=LGPL-2.1-or-later}

prepare() {
    case $package_component in
        libusb)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                ${udev:+--enable-udev=$udev} \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libusb)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libusb)
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
