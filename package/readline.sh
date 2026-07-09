: ${package_version:=8.3}
: ${package_source:=https://ftp.gnu.org/gnu/readline/readline-$package_version.tar.gz}

: ${prefix:=/usr}
: ${curses:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --with-curses=$curses \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    install -v -m644 $package_source_dir/doc/*.{ps,pdf,html,dvi} \
        $package_install_dir/$prefix/share/doc/readline-$package_version 2>/dev/null || true
}
