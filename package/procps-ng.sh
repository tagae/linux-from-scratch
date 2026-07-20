: ${package_version:=4.0.6}
: ${package_source:=https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-$package_version.tar.xz}
: ${package_source_sha256:=67bea6fbc3a42a535a0230c9e891e5ddfb4d9d39422d46565a2990d1ace15216}

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
