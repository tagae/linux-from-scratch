: ${package_version:=5.8.3}
: ${package_source:=https://github.com/tukaani-project/xz/releases/download/v$package_version/xz-$package_version.tar.xz}

: ${prefix:=/usr}
: ${static:=no}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-static=$static \
        --docdir=/usr/share/doc/xz-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
