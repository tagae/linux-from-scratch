: ${package_version:=1.4.21}
: ${package_source:=https://ftp.gnu.org/gnu/m4/m4-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    # gnulib's stackvma.c uses PATH_MAX without including <limits.h>;
    # glibc cross headers don't expose it transitively in this context.
    CFLAGS="-std=gnu11" \
    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --disable-nls
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
