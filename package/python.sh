: ${package_version:=3.14.5}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}

package_source_dir=$SOURCE_DIR/Python-$package_version

: ${prefix:=/usr}
: ${sysroot:=/}

prepare() {
    : ${build:=$(uname -m)-pc-linux-gnu}
    : ${host:=$build}

    # Cross-compiling Python requires a native Python build for host utilities
    $package_source_dir/configure \
        --prefix=$prefix \
        --build=$build \
        --host=$host \
        --enable-shared \
        --with-system-expat \
        --without-static-libpython \
        --with-sysroot=$sysroot \
        ac_cv_file__dev_ptmx=yes \
        ac_cv_file__dev_ptc=no
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
