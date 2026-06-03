: ${package_version:=23.7}
: ${package_source:=https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
