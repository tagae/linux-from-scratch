: ${package_version:=3.14.6}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}

package_source_dir=$SOURCE_DIR/Python-$package_version

prepare() {
    : ${shared:=yes}
    : ${optimizations:=yes}
    : ${static_libpython:=no}

    # Same patch the LFS book applies for this exact package/version — the
    # OpenSSL 4.0 part fixes what --with-openssl=/nonexistent used to just
    # sidestep (Python 3.14's _ssl.c referenced TLSv1_method, which OpenSSL
    # 4.0 dropped); it also carries a few unrelated upstream CVE fixes
    # bundled into the same "consolidated_fixes" patch.
    patch_source https://www.linuxfromscratch.org/patches/lfs/development/Python-$package_version-consolidated_fixes-1.patch

    # Cross-compiling Python requires a native Python build for host utilities.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${sysroot:+--with-sysroot=$sysroot} \
        ${shared:+--enable-shared=$shared} \
        ${system_expat:+--with-system-expat} \
        ${static_libpython:+--with-static-libpython=$static_libpython} \
        ${optimizations:+--enable-optimizations=$optimizations}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
