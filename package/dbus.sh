: ${package_version:=1.16.2}
: ${package_source:=https://dbus.freedesktop.org/releases/dbus/dbus-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
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
