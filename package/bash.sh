: ${package_version:=5.3}
: ${package_source:=https://ftp.gnu.org/gnu/bash/bash-$package_version.tar.gz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${bash_malloc:+--with-bash-malloc=$bash_malloc} \
        ${curses:+--with-curses=$curses} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    ln -sfv bash $package_install_dir$prefix/bin/sh
}
