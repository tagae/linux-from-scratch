: ${package_version:=1.0.8}
: ${package_source:=https://www.sourceware.org/pub/bzip2/bzip2-$package_version.tar.gz}
: ${package_source_hash:=sha256:ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269}
: ${package_description:=Block-sorting file compressor.}
: ${package_license:=bzip2-1.0.6}

prepare() {
    # The Makefiles only build in the source tree, so build from a copy of it.
    cp -Rp $package_source_dir/. .
}

build() {
    # The shared library and the program linked against it (bzip2-shared), then the rest.
    make -f Makefile-libbz2_so
    make clean
    make
}

install() {
    make install PREFIX=$package_install_dir$prefix

    # As LFS does: the programs link the shared library rather than the static one.
    cp -av libbz2.so.* $package_install_dir$prefix/lib/
    cp -v bzip2-shared $package_install_dir$prefix/bin/bzip2
    ln -sfv bzip2 $package_install_dir$prefix/bin/bunzip2
    ln -sfv bzip2 $package_install_dir$prefix/bin/bzcat
    rm -fv $package_install_dir$prefix/lib/libbz2.a

    # The Makefile installs its manual pages unconditionally.
    rm -rfv $package_install_dir$prefix/man
}
