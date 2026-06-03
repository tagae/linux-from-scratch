: ${package_version:=5.3}
: ${package_source:=https://ftp.gnu.org/gnu/bash/bash-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --without-bash-malloc \
        --with-installed-readline \
        --with-curses
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    ln -sfv bash $package_install_dir/$prefix/bin/sh
}
