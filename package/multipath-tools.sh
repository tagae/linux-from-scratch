: ${package_version:=0.14.3}
: ${package_source:=https://github.com/opensvc/multipath-tools/archive/$package_version/multipath-tools-$package_version.tar.gz}
: ${package_source_hash:=sha256:206ab1635b09309974e2fdf3bbd1825254638dc9b3d2bbd436d1105cd518d379}
: ${package_description:=Device-mapper multipath tools.}
: ${package_license:=GPL-2.0-or-later AND LGPL-2.0-only}

case ${package_component:-} in
    kpartx) ;;
    *) bail "multipath-tools: only the 'kpartx' component is supported (got '${package_component:-}')" ;;
esac

prepare() {
    make -C $package_source_dir -f create-config.mk
}

build() {
    case $package_component in
        kpartx)
            make -C $package_source_dir/kpartx CC=gcc
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        kpartx)
            make -C $package_source_dir/kpartx install \
                 DESTDIR=$package_install_dir CC=gcc prefix=${prefix:-/usr}
            ;;
        *)
            default_build
            ;;
    esac
}
