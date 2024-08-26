: ${package_version:=3.8.2}
: ${package_source:=https://ftp.gnu.org/gnu/bison/bison-$package_version.tar.xz}

: ${prefix:=/usr}
: ${sysroot:=/}

prepare() {
    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --target=$target \
        --with-sysroot=$sysroot \
        --with-arch=$arch \
        --with-float=$float \
        --with-fpu=$fpu \
        --with-tune=$tune \
        --disable-nls
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
