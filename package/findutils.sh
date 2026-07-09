: ${package_version:=4.10.0}
: ${package_source:=https://ftp.gnu.org/gnu/findutils/findutils-$package_version.tar.xz}

: ${prefix:=/usr}
: ${localstatedir:=/var/lib/locate}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --localstatedir=$localstatedir
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
