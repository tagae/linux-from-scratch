: ${package_version:=6.3.0}
: ${package_source:=https://ftp.gnu.org/gnu/gmp/gmp-$package_version.tar.xz}
: ${package_source_hash:=sha256:a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898}

# build=: only matters for a target build. No-op for native use.
: ${build:=$(gcc -dumpmachine)}

prepare() {
    CFLAGS=-std=gnu17 \
    CC_FOR_BUILD=gcc \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${cxx:+--enable-cxx=$cxx} \
        --disable-static \
        --docdir=/usr/share/doc/gmp-$package_version
}

build() {
    make
    make check
}

install() {
    make install DESTDIR=$package_install_dir
}
