: ${package_version:=3.12}
: ${package_source:=https://ftp.gnu.org/gnu/diffutils/diffutils-$package_version.tar.xz}

: ${prefix:=/usr}
: ${nls:=no}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    # Pre-cache gnulib run tests; fix PATH_MAX missing in cross-compiled stackvma.c.
    printf 'gl_cv_func_strcasecmp_works=yes\ngl_cv_func_c_stack=no\n' > config.cache

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --enable-nls=$nls \
        gl_cv_func_strcasecmp_works=yes
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
