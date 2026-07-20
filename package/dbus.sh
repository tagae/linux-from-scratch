: ${package_version:=1.16.2}
: ${package_source:=https://dbus.freedesktop.org/releases/dbus/dbus-$package_version.tar.xz}
: ${package_source_sha256:=0ba2a1a4b16afe7bceb2c07e9ce99a8c2c3508e5dec290dbb643384bd6beb7e2}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --runstatedir=/run \
        --disable-static \
        --disable-doxygen-docs \
        --disable-xml-docs \
        --docdir=/usr/share/doc/dbus-$package_version \
        --with-system-socket=/run/dbus/system_bus_socket
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
