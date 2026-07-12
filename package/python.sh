: ${package_version:=3.14.6}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}

package_source_dir=$SOURCE_DIR/Python-$package_version

prepare() {
    # Cross-compiling Python requires a native Python build for host utilities.
    # --with-openssl points at a nonexistent dir on purpose: we don't need
    # Python's own SSL support here (wget handles HTTPS fetching, not
    # Python), and our openssl is too new for it anyway — Python 3.14's
    # _ssl.c references TLSv1_method, which OpenSSL 4.0 dropped. Pointing
    # at a missing dir makes configure's optional _ssl module detection
    # fail gracefully rather than build-then-fail-to-import.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${sysroot:+--with-sysroot=$sysroot} \
        --enable-shared \
        ${system_expat:+--with-system-expat} \
        --without-static-libpython \
        --with-openssl=${openssl:-/nonexistent} \
        ac_cv_file__dev_ptmx=yes \
        ac_cv_file__dev_ptc=no
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
