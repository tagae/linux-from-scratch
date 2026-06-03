: ${package_version:=1.0.8}
: ${package_source:=https://sourceware.org/pub/bzip2/bzip2-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$(uname -m)-pc-linux-gnu}
    : ${host:=$build}
    : ${target:=$host}

    sed -i 's|/usr/local|$(PREFIX)|g' $package_source_dir/Makefile
}

build() {
    make -C $package_source_dir CC=$target-gcc AR=$target-ar RANLIB=$target-ranlib \
        -f Makefile-libbz2_so
    make -C $package_source_dir clean
    make -C $package_source_dir CC=$target-gcc AR=$target-ar RANLIB=$target-ranlib
}

install() {
    make -C $package_source_dir install PREFIX=$package_install_dir/$prefix
    cp -v $package_source_dir/libbz2.so.* $package_install_dir/$prefix/lib
    ln -sfv libbz2.so.1.0.8 $package_install_dir/$prefix/lib/libbz2.so.1.0
    ln -sfv libbz2.so.1.0 $package_install_dir/$prefix/lib/libbz2.so
    rm -fv $package_install_dir/$prefix/lib/libbz2.a
}
