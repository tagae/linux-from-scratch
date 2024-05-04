# https://gcc.gnu.org/install/build.html

: ${package_version:=13.2.0}
: ${package_source:=https://ftp.gnu.org/gnu/gcc/gcc-$package_version/gcc-$package_version.tar.xz}

: ${sysroot:=/}
: ${prefix:=/usr}
: ${newlib:=no}
: ${headers:=$sysroot/usr/include}
: ${build_time_sysroot:=$sysroot}
: ${build_sysroot:=$sysroot}
: ${shared:=yes}
: ${threads:=yes}
: ${libatomic:=yes}
: ${libgomp:=yes}
: ${libquadmath:=yes}
: ${libssp:=yes}
: ${libvtv:=yes}
: ${libstdcxx:=yes}
: ${languages:=c,c++}

fetch() {
    default_fetch
    (
        cd $package_source_dir
        ./contrib/download_prerequisites
    )
}

prepare() {
    # https://gcc.gnu.org/install/configure.html
    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --target=$target \
        --with-arch=$arch \
        --with-float=$float \
        --with-fpu=$fpu \
        --with-tune=$tune \
        --with-newlib=$newlib \
        --with-headers=$headers \
        --with-build-time-tools=$build_time_sysroot \
        --with-build-sysroot=$build_sysroot \
        --enable-shared=$shared \
        --enable-threads=$threads \
        --enable-libatomic=$libatomic \
        --enable-libgomp=$libgomp \
        --enable-libquadmath=$libquadmath \
        --enable-libssp=$libssp \
        --enable-libvtv=$libvtv \
        --enable-libstdcxx=$libstdcxx \
        --enable-languages=$languages \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-multilib \
        --disable-nls
}

build() {
    make all-gcc all-target-libgcc
}

install() {
    make install-gcc install-target-libgcc DESTDIR=$package_install_dir
}
