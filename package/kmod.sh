# Kernel module loading.

: ${package_version:=34.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${openssl:+--with-openssl=$openssl} \
        ${xz:+--with-xz=$xz} \
        ${zstd:+--with-zstd=$zstd} \
        ${zlib:+--with-zlib=$zlib} \
        ${manpages:+--enable-manpages=$manpages}
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
