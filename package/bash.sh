: ${package_version:=5.3}
: ${package_source:=https://ftp.gnu.org/gnu/bash/bash-$package_version.tar.gz}

: ${prefix:=/usr}
: ${bash_malloc:=no}
: ${curses:=no}
: ${nls:=no}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --with-bash-malloc=$bash_malloc \
        --with-curses=$curses \
        --enable-nls=$nls
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    ln -sv bash $package_install_dir$prefix/bin/sh
}
