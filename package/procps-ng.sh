: ${package_version:=4.0.6}
: ${package_source:=https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-$package_version.tar.xz}

: ${prefix:=/usr}
: ${kill:=yes}
: ${systemd:=no}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-static \
        --enable-kill=$kill \
        --docdir=/usr/share/doc/procps-ng-$package_version \
        --with-systemd=$systemd
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
