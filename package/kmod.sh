# Kernel module loading.

: ${package_version:=34.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$package_version.tar.xz}

: ${prefix:=/usr}
: ${openssl:=no}
: ${xz:=yes}
: ${zstd:=yes}
: ${zlib:=yes}
: ${manpages:=yes}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --with-openssl=$openssl \
        --with-xz=$xz \
        --with-zstd=$zstd \
        --with-zlib=$zlib \
        --enable-manpages=$manpages
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
