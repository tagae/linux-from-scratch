: ${package_version:=0.195}
: ${package_source:=https://sourceware.org/ftp/elfutils/$package_version/elfutils-$package_version.tar.bz2}
: ${package_source_hash:=sha256:37629fdf7f1f3dc2818e138fca2b8094177d6c2d0f701d3bb650a561218dc026}
: ${package_description:=ELF object file access library and utilities.}
: ${package_license:=GPL-3.0-or-later AND (GPL-2.0-or-later OR LGPL-3.0-or-later)}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${nls:+--enable-nls=$nls} \
        --disable-debuginfod \
        --disable-libdebuginfod \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
