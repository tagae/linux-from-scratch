: ${package_version:=3.14.7}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}
: ${package_source_hash:=sha256:3b48dac8fb59f62eaa67ac83c1eb12bda1b7a08406dd286e252c11a66be27f81}
: ${package_description:=Python programming language.}
: ${package_license:=Python-2.0.1}

package_source_dir=$SOURCE_DIR/Python-$package_version

: ${build_python:=$TOOL_DIR/usr/bin/python3}

prepare() {
    : ${shared:=yes}
    : ${optimizations:=$([ -n "${host:-}" ] && echo no || echo yes)}
    : ${static_libpython:=no}

    patch_source https://www.linuxfromscratch.org/patches/lfs/$lfs_version/Python-$package_version-openssl_4-1.patch \
        sha256:707a0c457192ac2f3b5b8a51481bc5ebd12db22d57c1dbe0256138ee6e070792

    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${sysroot:+--with-sysroot=$sysroot} \
        ${host:+--with-build-python=$build_python} \
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
