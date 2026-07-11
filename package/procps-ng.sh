: ${package_version:=4.0.6}
: ${package_source:=https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        ${kill:+--enable-kill=$kill} \
        --docdir=/usr/share/doc/procps-ng-$package_version \
        ${systemd:+--with-systemd=$systemd}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
