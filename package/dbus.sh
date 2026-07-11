: ${package_version:=1.16.2}
: ${package_source:=https://dbus.freedesktop.org/releases/dbus/dbus-$package_version.tar.xz}

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
