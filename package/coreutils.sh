: ${package_version:=9.11}
: ${package_source:=https://ftp.gnu.org/gnu/coreutils/coreutils-$package_version.tar.xz}

: ${prefix:=/usr}
: ${install_program:=}
: ${no_install_program:=}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-install-program=$install_program \
        --enable-no-install-program=$no_install_program
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
