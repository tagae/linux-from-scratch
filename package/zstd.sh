: ${package_version:=1.5.7}
: ${package_source:=https://github.com/facebook/zstd/releases/download/v$package_version/zstd-$package_version.tar.gz}

: ${prefix:=/usr}

build() {
    make -C $package_source_dir \
        CC=$target-gcc \
        AR=$target-ar \
        prefix=$prefix
}

install() {
    make -C $package_source_dir \
        CC=$target-gcc \
        AR=$target-ar \
        prefix=$package_install_dir/$prefix \
        install
    rm -fv $package_install_dir/$prefix/lib/libzstd.a
}
