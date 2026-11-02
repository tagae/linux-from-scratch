: ${package_version:=4.0.49}
: ${package_source:=https://ftp.gnu.org/gnu/mtools/mtools-$package_version.tar.gz}
: ${package_source_hash:=sha256:10cd1111da87bf2400a380c1639a6cba8bfb937a24f9c51f5f88d393ae5f6f76}
: ${package_description:=Utilities to access FAT file systems without mounting them.}
: ${package_license:=GPL-3.0-or-later}

# mtools converts names to the FAT code page with its own tables rather than with iconv: the glibc
# of the tools finds its conversion modules only where GCONV_PATH points, as in lfs_tools_build.
prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --without-x \
        ac_cv_header_iconv_h=no
}

build() {
    make
}

# The programs, without the manual (whose info pages make would remake, with makeinfo).
install() {
    make install-links DESTDIR=$package_install_dir
}
