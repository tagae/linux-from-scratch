: ${package_version:=2.03.38}
: ${package_source:=https://sourceware.org/ftp/lvm2/LVM2.$package_version.tgz}
: ${package_source_hash:=sha256:322d44bf40de318e6e6b52c56999aaeb86b16c8267187ac2e01a44d4dc526960}
: ${package_description:=Logical volume manager and device-mapper library.}
: ${package_license:=GPL-2.0-only AND LGPL-2.1-only}

package_source_dir=$SOURCE_DIR/LVM2.$package_version

case $package_component in
    device-mapper) ;;
    *) bail "lvm2: only the 'device-mapper' component is supported (got '${package_component:-}')" ;;
esac

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --without-udev \
        --without-systemd \
        --disable-selinux \
        --disable-readline
}

build() {
    make
}

install() {
    case $package_component in
        device-mapper)
            make -C libdm install DESTDIR=$package_install_dir
            ;;
        *)
            default_install
            ;;
    esac
}
