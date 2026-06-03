: ${package_version:=2.46.0}
: ${package_source:=https://ftp.gnu.org/gnu/binutils/binutils-$package_version.tar.xz}

: ${prefix:=/usr}
: ${sysroot:=/}
: ${gprofng:=yes}

prepare() {
    : ${build:=$($package_source_dir/config.guess)}
    : ${host:=$build}
    : ${target:=$host}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --target=$target \
        --with-sysroot=$sysroot \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        --with-default-hash-style=gnu \
        --enable-gprofng=$gprofng \
        --disable-multilib \
        --disable-nls \
        --disable-werror
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
