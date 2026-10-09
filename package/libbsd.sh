# BSD utility functions on glibc.

: ${package_version:=0.12.2}
: ${package_source:=https://libbsd.freedesktop.org/releases/libbsd-$package_version.tar.xz}
: ${package_source_hash:=sha256:b88cc9163d0c652aaf39a99991d974ddba1c3a9711db8f1b5838af2a14731014}

: ${build:=$(gcc -dumpmachine)}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${host:+--with-sysroot=$INSTALL_DIR/$SYSTEM_KEY} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
