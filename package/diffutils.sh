: ${package_version:=3.12}
: ${package_source:=https://ftp.gnu.org/gnu/diffutils/diffutils-$package_version.tar.xz}
: ${package_source_sha256:=7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd}

prepare() {
    # Pre-cache gnulib run tests; fix PATH_MAX missing in cross-compiled stackvma.c.
    printf 'gl_cv_func_strcasecmp_works=yes\ngl_cv_func_c_stack=no\n' > config.cache

    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${nls:+--enable-nls=$nls} \
        gl_cv_func_strcasecmp_works=yes
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
