: ${package_version:=23.7}
: ${package_source:=https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-$package_version.tar.xz}
: ${package_source_hash:=sha256:58c55d9c1402474065adae669511c191de374b0871eec781239ab400b907c327}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
