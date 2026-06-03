: ${package_version:=2.3.2}
: ${package_source:=https://download.savannah.gnu.org/releases/acl/acl-$package_version.tar.xz}

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
