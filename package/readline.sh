: ${package_version:=8.3}
: ${package_source:=https://ftp.gnu.org/gnu/readline/readline-$package_version.tar.gz}
: ${package_source_hash:=sha256:fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${curses:+--with-curses=$curses} \
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
