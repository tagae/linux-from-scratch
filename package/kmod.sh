# Kernel module loading.

: ${package_version:=34.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$package_version.tar.xz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --without-openssl \
        --without-xz \
        --without-zstd \
        --without-zlib \
        --disable-manpages
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir

    for tool in depmod insmod modinfo modprobe rmmod; do
        ln -sfv kmod $package_install_dir/$prefix/bin/$tool
    done
    ln -sfv kmod $package_install_dir/$prefix/bin/lsmod
}
