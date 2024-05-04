: ${package_version:=2.42}
: ${package_source:=https://ftp.gnu.org/gnu/binutils/binutils-$package_version.tar.xz}

: ${prefix:=/usr}
: ${sysroot:=/}
: ${gprofng:=yes}

#        --with-libiconv-prefix=/opt/homebrew/opt/libiconv \
#        --disable-lipquadmath \
#        --disable-libquadmath-support

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
        --with-default-hash-style=gnu \
        --enable-gprofng=$gprofng \
        --disable-multilib \
        --disable-nls
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
