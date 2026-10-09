: ${package_version:=6.3.0}
: ${package_source:=https://ftp.gnu.org/gnu/gmp/gmp-$package_version.tar.xz}
: ${package_source_hash:=sha256:a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898}
: ${package_description:=GNU multiple-precision arithmetic library.}
: ${package_license:=LGPL-3.0-or-later OR GPL-2.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${cxx:+--enable-cxx=$cxx} \
        --disable-static
}

build() {
    make
    make check
}

install() {
    make install DESTDIR=$package_install_dir
}
