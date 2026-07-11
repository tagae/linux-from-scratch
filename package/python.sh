: ${package_version:=3.14.6}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}

package_source_dir=$SOURCE_DIR/Python-$package_version

prepare() {
    # Cross-compiling Python requires a native Python build for host utilities
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --enable-shared \
        ${system_expat:+--with-system-expat} \
        --without-static-libpython \
        ${sysroot:+--with-sysroot=$sysroot} \
        ac_cv_file__dev_ptmx=yes \
        ac_cv_file__dev_ptc=no
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
