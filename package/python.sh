: ${package_version:=3.13.5}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}

package_source_dir=$SOURCE_DIR/Python-$package_version

: ${prefix:=/usr}
: ${sysroot:=/}

prepare() {
    $package_source_dir/configure \
        --prefix=$prefix \
        --build=$build \
        --host=$host \
        --target=$target \
        --enable-shared \
        --with-system-expat \
        --enable-optimizations \
        --without-static-libpython
}
