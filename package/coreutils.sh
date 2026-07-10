: ${package_version:=9.11}
: ${package_source:=https://ftp.gnu.org/gnu/coreutils/coreutils-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${install_program:+--enable-install-program=$install_program} \
        ${no_install_program:+--enable-no-install-program=$no_install_program}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
