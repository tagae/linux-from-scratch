: ${package_version:=1.5.7}
: ${package_source:=https://github.com/facebook/zstd/releases/download/v$package_version/zstd-$package_version.tar.gz}
: ${package_source_hash:=sha256:eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3}

build() {
    make -C $package_source_dir \
        CC=$target-gcc \
        AR=$target-ar \
        ${prefix:+prefix=$prefix}
}

install() {
    make -C $package_source_dir \
        CC=$target-gcc \
        AR=$target-ar \
        ${prefix:+prefix=$package_install_dir/$prefix} \
        install
    rm -fv $package_install_dir/$prefix/lib/libzstd.a
}
